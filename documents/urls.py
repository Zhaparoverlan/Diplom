from django.urls import path
from .views import DocumentListCreateAPIView, DocumentDetailAPIView, DashboardStatsAPIView

urlpatterns = [
    path('', DocumentListCreateAPIView.as_view(), name='doc-list-create'),
    path('<int:pk>/', DocumentDetailAPIView.as_view(), name='doc-detail'),
    path('stats/', DashboardStatsAPIView.as_view(), name='doc-stats'),
]