from django.urls import path
from .views import RegisterCompanyView

urlpatterns = [
    # Путь будет: /api/users/register/
    path('register/', RegisterCompanyView.as_view(), name='register_company'),
]