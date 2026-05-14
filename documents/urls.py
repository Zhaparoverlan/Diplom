from django.urls import path
from .views import (
    DocumentListCreateAPIView,
    DocumentDetailAPIView,
    DocumentStatusAPIView,
    DocumentApproveAPIView,
    DashboardStatsAPIView,
)

urlpatterns = [
    path('create/',          DocumentListCreateAPIView.as_view(), name='doc-list-create'),
    path('all/',             DocumentListCreateAPIView.as_view(), name='doc-list-all'),
    path('stats/',           DashboardStatsAPIView.as_view(),     name='doc-stats'),
    path('<int:pk>/',         DocumentDetailAPIView.as_view(),     name='doc-detail'),
    path('<int:pk>/status/',  DocumentStatusAPIView.as_view(),     name='doc-status'),
    path('<int:pk>/approve/', DocumentApproveAPIView.as_view(),    name='doc-approve'),
]
