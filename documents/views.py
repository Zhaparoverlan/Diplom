from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from django.db.models import Sum
from .models import Document
from .serializers import DocumentSerializer

class DocumentListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = DocumentSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = (MultiPartParser, FormParser)

    def get_queryset(self):
        user = self.request.user
        base_qs = Document.objects.filter(company=user.company)

        # Если владелец или менеджер — видят всё внутри компании
        if user.role in ['owner', 'manager']:
            return base_qs.order_by('-created_at')
        
        # Если обычный сотрудник — видит только то, что загрузил сам
        return base_qs.filter(author=user).order_by('-created_at')

    def perform_create(self, serializer):
        # Автоматически проставляем автора и компанию при создании
        serializer.save(
            author=self.request.user,
            owner=self.request.user,
            company=self.request.user.company,
            status='draft' # По ТЗ при загрузке всегда статус "Черновик"
        )

    def list(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = self.get_serializer(queryset, many=True)
        
        # Расширенный ответ для Flutter (удобно для заголовка профиля)
        return Response({
            'user_info': {
                'username': request.user.username,
                'role': request.user.role,
                'company_name': request.user.company.name if request.user.company else "No Company"
            },
            'documents': serializer.data
        })

class DashboardStatsAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        # Считаем только документы компании юзера
        company_docs = Document.objects.filter(company=user.company)

        # Если сотрудник — считаем только его доки, если босс — всей компании
        if user.role == 'employee':
            user_docs = company_docs.filter(author=user)
        else:
            user_docs = company_docs

        stats = {
            "total_count": user_docs.count(),
            "pending_count": user_docs.filter(status='pending').count(),
            "approved_count": user_docs.filter(status='approved').count(),
            # Считаем общую сумму всех одобренных расходов (пункт 7.7 ТЗ)
            "total_expenses": user_docs.filter(status='approved').aggregate(Sum('amount'))['amount__sum'] or 0,
            "user_role": user.role,
            "user_name": user.username,
        }

        return Response(stats)

class DocumentDetailAPIView(generics.RetrieveUpdateDestroyAPIView):
    """Класс для просмотра одного документа, его удаления или смены статуса"""
    serializer_class = DocumentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Опять же, доступ только к документам своей компании
        return Document.objects.filter(company=self.request.user.company)

    def perform_update(self, serializer):
        user = self.request.user
        new_status = self.request.data.get('status')

        # Логика Workflow из ТЗ (пункт 6): Employee не может одобрять
        if new_status == 'approved' and user.role == 'employee':
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Сотрудники не могут одобрять документы.")

        serializer.save()