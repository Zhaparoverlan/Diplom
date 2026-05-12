from django.urls import path
from .views import RegisterCompanyView, UserMeView, EmployeeListView, UserDeleteAPIView

urlpatterns = [
    path('register/', RegisterCompanyView.as_view(), name='register_company'),
    path('me/', UserMeView.as_view(), name='user-me'),
    path('employees/', EmployeeListView.as_view(), name='employee-list'),
    path('<int:id>/delete/', UserDeleteAPIView.as_view(), name='user-delete'),
]