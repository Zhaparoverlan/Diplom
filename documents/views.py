from __future__ import annotations

import logging

from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.views import APIView
from django.db.models import Q, Sum
from .models import Document
from .serializers import DocumentSerializer

logger = logging.getLogger(__name__)

_IMAGE_EXTS = ('.png', '.jpg', '.jpeg')


class DocumentListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = DocumentSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = (MultiPartParser, FormParser)

    def get_queryset(self):
        user = self.request.user
        qs   = Document.objects.filter(company=user.company)

        if user.role == 'employee':
            qs = qs.filter(author=user)

        p = self.request.query_params
        if p.get('status'):
            qs = qs.filter(status=p['status'])
        if p.get('category'):
            qs = qs.filter(category=p['category'])
        if p.get('search'):
            qs = qs.filter(
                Q(title__icontains=p['search']) | Q(supplier__icontains=p['search'])
            )
        if p.get('min_price'):
            qs = qs.filter(amount__gte=p['min_price'])
        if p.get('max_price'):
            qs = qs.filter(amount__lte=p['max_price'])
        if p.get('date_from'):
            qs = qs.filter(created_at__date=p['date_from'])

        return qs.order_by('-created_at')

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        instance = serializer.instance
        instance.refresh_from_db()
        out = self.get_serializer(instance)
        headers = self.get_success_headers(out.data)
        return Response(out.data, status=status.HTTP_201_CREATED, headers=headers)

    def perform_create(self, serializer):
        instance = serializer.save(
            author=self.request.user,
            owner=self.request.user,
            company=self.request.user.company,
            status='pending',
            last_modified_by=self.request.user,
        )

        # ── Sync pHash duplicate check (images only) ──────────────────────────
        is_image = bool(
            instance.file
            and instance.file.name.lower().endswith(_IMAGE_EXTS)
        )

        if is_image:
            try:
                from .services import compute_phash, phash_distance
                h = compute_phash(instance.file.path)
                if h:
                    instance.phash = h
                    existing = list(
                        Document.objects
                        .filter(company=instance.company)
                        .exclude(pk=instance.pk)
                        .exclude(phash__isnull=True)
                        .exclude(phash='')
                        .values_list('phash', flat=True)
                    )
                    # Empty DB → no existing hashes → min_dist defaults to 64 (safe)
                    min_dist = min(
                        (phash_distance(h, other) for other in existing),
                        default=64,
                    )
                    if min_dist < 5:
                        instance.status = 'duplicate'
                    instance.save(update_fields=['phash', 'status'])

                    if instance.status == 'duplicate':
                        logger.info(
                            "Duplicate doc=%s min_dist=%d", instance.pk, min_dist
                        )
                        return  # No async task; Flutter reads status='duplicate'
            except Exception:
                logger.exception("pHash check failed for doc=%s", instance.pk)

        # ── Queue OCR asynchronously via Celery ──────────────────────────────
        from .tasks import process_document
        try:
            task = process_document.delay(instance.pk)
            logger.info(
                "process_document queued async doc=%s celery_task_id=%s",
                instance.pk, task.id,
            )
        except Exception:
            # Broker unavailable — fall back to in-process execution so the
            # document does not stay stuck in 'pending' forever.
            logger.warning(
                "Celery broker unavailable for doc=%s — running OCR in-process",
                instance.pk,
            )
            try:
                process_document.apply(args=[instance.pk])
            except Exception:
                logger.exception("Fallback OCR failed for doc=%s", instance.pk)
                instance.status = 'needs_verification'
                instance.save(update_fields=['status'])


class DocumentStatusAPIView(APIView):
    """Lightweight polling endpoint — GET /api/documents/<pk>/status/"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        doc = get_object_or_404(Document, pk=pk, company=request.user.company)
        return Response({
            'id':               doc.pk,
            'status':           doc.status,
            'status_display':   doc.get_status_display(),
            'confidence_score': doc.confidence_score,
        })


class DashboardStatsAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        qs   = Document.objects.filter(company=user.company)
        if user.role == 'employee':
            qs = qs.filter(author=user)

        stats = {
            'total_count':   qs.count(),
            'pending_count': qs.filter(status='pending').count(),
            'ready_count':   qs.filter(status='ready').count(),
            'flagged_count': qs.filter(
                status__in=['duplicate', 'needs_verification', 'needs_approval']
            ).count(),
            'total_expenses': (
                qs.filter(status='ready')
                  .aggregate(Sum('amount'))['amount__sum'] or 0
            ),
            'user_role': user.role,
            'user_name': user.username,
        }
        return Response(stats)


class DocumentApproveAPIView(APIView):
    """
    POST /api/documents/<pk>/approve/
    Transitions needs_approval | needs_verification | duplicate → ready.
    Only owners and managers may call this endpoint.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        if request.user.role == 'employee':
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Только владелец или менеджер может одобрять документы.")

        doc = get_object_or_404(Document, pk=pk, company=request.user.company)

        if doc.status not in ('needs_approval', 'needs_verification', 'duplicate'):
            return Response(
                {'detail': f'Нельзя одобрить документ со статусом «{doc.get_status_display()}».'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        doc.status           = 'ready'
        doc.last_modified_by = request.user
        doc.save(update_fields=['status', 'last_modified_by', 'updated_at'])
        logger.info(
            "Document %s approved (was: %s) by %s",
            doc.pk, doc.status, request.user.username,
        )
        return Response(DocumentSerializer(doc).data, status=status.HTTP_200_OK)


class DocumentDetailAPIView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class   = DocumentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Document.objects.filter(company=self.request.user.company)

    def perform_update(self, serializer):
        # status is read_only in the serializer — this save only touches
        # editable fields (supplier, amount, doc_date, category, title).
        serializer.save(last_modified_by=self.request.user)

    def perform_destroy(self, instance):
        if self.request.user.role == 'employee':
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Только владелец или менеджер может удалять документы.")
        instance.delete()
