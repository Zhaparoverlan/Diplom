from django.urls import path

from .views import (
    ChangePasswordView,
    EmployeeListView,
    EmployeeUpdateView,
    RegisterCompanyView,
    UserDeleteAPIView,
    UserMeView,
)

urlpatterns = [
    path('register/', RegisterCompanyView.as_view(), name='register_company'),
    path('me/', UserMeView.as_view(), name='user-me'),
    path('me/change-password/', ChangePasswordView.as_view(), name='change-password'),
    path('employees/', EmployeeListView.as_view(), name='employee-list'),
    path('<int:id>/delete/', UserDeleteAPIView.as_view(), name='user-delete'),
    path('<int:id>/update/', EmployeeUpdateView.as_view(), name='user-update'),
]
