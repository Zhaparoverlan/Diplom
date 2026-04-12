from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    
    # Роли строго по ТЗ (пункт 3 и 6)
    OWNER = 'owner'
    MANAGER = 'manager'
    EMPLOYEE = 'employee'
    
    ROLES = (
        (OWNER, 'Владелец'),
        (MANAGER, 'Менеджер'),
        (EMPLOYEE, 'Сотрудник'),
    )
    
    # Обязательные поля по ТЗ (пункт 5)
    role = models.CharField(
        max_length=20, 
        choices=ROLES, 
        default=EMPLOYEE,
        verbose_name="Роль"
    )
    
    # Multi-tenancy (пункт 4 и 5)
    company = models.ForeignKey(
        'company.Company',
        on_delete=models.CASCADE,
        related_name='users',
        verbose_name="Компания",
        null=True,   # Позволяет БД хранить пустые значения (для админа)
        blank=True 
    )
    
    # AbstractUser уже содержит: username, email, first_name, last_name
    
    class Meta:
        verbose_name = "Пользователь"
        verbose_name_plural = "Пользователи"
        # Уникальность email в рамках компании (хорошая практика)
        unique_together = ['email', 'company']
    
    def __str__(self):
        company_name = self.company.name if self.company else "Без компании"
        return f"{self.email or self.username} ({self.get_role_display()}) - {company_name}"