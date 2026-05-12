import logging

from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from django.db.models import Sum, Q
from .models import Document
from .serializers import DocumentSerializer
from .services import extract_text_from_image
import re

logger = logging.getLogger(__name__)


class DocumentListCreateAPIView(generics.ListCreateAPIView):
    """
    Основной класс: создание документов с OCR и получение списка с ФИЛЬТРАЦИЕЙ.
    """
    serializer_class = DocumentSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = (MultiPartParser, FormParser)

    def get_queryset(self):
        user = self.request.user
        # Базовый фильтр по компании
        queryset = Document.objects.filter(company=user.company)

        # Ограничение для обычных сотрудников (видят только свое)
        if user.role == 'employee':
            queryset = queryset.filter(author=user)

        # --- БЛОК ФИЛЬТРАЦИИ (Добавлено из твоего DocumentListView) ---
        status_param = self.request.query_params.get('status')
        category = self.request.query_params.get('category')
        search = self.request.query_params.get('search')
        min_price = self.request.query_params.get('min_price')
        max_price = self.request.query_params.get('max_price')
        date_from = self.request.query_params.get('date_from')

        if status_param:
            queryset = queryset.filter(status=status_param)
        if category:
            queryset = queryset.filter(category=category)
        if search:
            # Живой поиск по названию или поставщику
            queryset = queryset.filter(Q(title__icontains=search) | Q(supplier__icontains=search))
        if min_price:
            queryset = queryset.filter(amount__gte=min_price)
        if max_price:
            queryset = queryset.filter(amount__lte=max_price)
        if date_from:
            queryset = queryset.filter(created_at__date=date_from)

        return queryset.order_by('-created_at')

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        instance = serializer.instance
        instance.refresh_from_db()
        output = self.get_serializer(instance)
        headers = self.get_success_headers(output.data)
        return Response(output.data, status=status.HTTP_201_CREATED, headers=headers)

    def extract_data_from_text(self, text):
        # Сумма: типичные подписи на чеках (рус/англ); дальше число с пробелами/запятыми
        amount_pattern = (
            r'(?:Итого|ИТОГО|Сумма|Всего|Total|ИТОГ|К\s*оплате|'
            r'Всего\s*к\s*оплате|Сумма\s*к\s*оплате|Amount)[:\s\=\-\_]*([\d\s\.,\'’]+)'
        )
        match = re.search(amount_pattern, text, re.IGNORECASE)
        if match:
            raw_val = match.group(1).strip()
            raw_val = raw_val.replace(',', '.')
            clean_amount = re.sub(r'[^\d.]', '', raw_val)
            if clean_amount.count('.') > 1:
                parts = clean_amount.split('.')
                clean_amount = "".join(parts[:-1]) + "." + parts[-1]
            try:
                return float(clean_amount)
            except ValueError:
                return 0.0
        return 0.0
    
    def perform_create(self, serializer):
        # При создании ставим статус draft и привязываем к юзеру
        instance = serializer.save(
            author=self.request.user,
            owner=self.request.user,
            company=self.request.user.company,
            status='pending'
        )
        
        # OCR: только PaddleOCR (см. documents.services).
        if instance.file and instance.file.name.lower().endswith(('.png', '.jpg', '.jpeg')):
            try:
                extracted_text, ocr_conf = extract_text_from_image(instance.file.path)
                extracted_text = (extracted_text or "").strip()

                if extracted_text:
                    instance.raw_text = extracted_text
                    instance._ocr_confidence = ocr_conf
                    found_amount = self.extract_data_from_text(extracted_text)
                    if found_amount > 0:
                        instance.amount = found_amount

                    lines = [line.strip() for line in extracted_text.split('\n') if len(line.strip()) > 5]
                    if lines:
                        instance.supplier = lines[0][:100]

                    instance.save()
                    logger.info(
                        "Document %s OCR done confidence=%.4f amount=%s",
                        instance.pk,
                        ocr_conf,
                        instance.amount,
                    )
                else:
                    instance._ocr_confidence = ocr_conf
            except Exception:
                logger.exception("OCR error document_id=%s", getattr(instance, "pk", None))

class DashboardStatsAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        company_docs = Document.objects.filter(company=user.company)

        if user.role == 'employee':
            user_docs = company_docs.filter(author=user)
        else:
            user_docs = company_docs

        stats = {
            "total_count": user_docs.count(),
            "pending_count": user_docs.filter(status='pending').count(),
            "approved_count": user_docs.filter(status='approved').count(),
            "total_expenses": user_docs.filter(status='approved').aggregate(Sum('amount'))['amount__sum'] or 0,
            "user_role": user.role,
            "user_name": user.username,
        }
        return Response(stats)

class DocumentDetailAPIView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = DocumentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Document.objects.filter(company=self.request.user.company)

    def perform_update(self, serializer):
        user = self.request.user
        # Получаем статус из входящих данных
        new_status = self.request.data.get('status')
        
        # Если сотрудник редактирует документ, он должен остаться или стать 'pending'
        if user.role == 'employee':
            # Если статус пытаются поставить 'approved' — запрещаем
            if new_status == 'approved':
                from rest_framework.exceptions import PermissionDenied
                raise PermissionDenied("Сотрудники не могут одобрять документы.")
            
            # Гарантируем, что после сохранения статус будет 'pending', а не 'draft'
            serializer.save(status='pending')
        else:
            # Если менеджер или владелец — сохраняем как есть
            serializer.save()

    def perform_destroy(self, instance):
        if self.request.user.role == 'employee' and instance.author != self.request.user:
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Вы не можете удалить чужой документ.")
        instance.delete()