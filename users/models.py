from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):

    OWNER = 'owner'
    MANAGER = 'manager'
    EMPLOYEE = 'employee'

    ROLES = (
        (OWNER, 'Владелец'),
        (MANAGER, 'Менеджер'),
        (EMPLOYEE, 'Сотрудник'),
    )

    role = models.CharField(
        max_length=20,
        choices=ROLES,
        default=EMPLOYEE,
        verbose_name="Роль",
    )
    company = models.ForeignKey(
        'company.Company',
        on_delete=models.CASCADE,
        related_name='users',
        verbose_name="Компания",
        null=True,
        blank=True,
    )

    avatar = models.ImageField(
        upload_to='avatars/',
        null=True,
        blank=True,
        verbose_name="Аватар",
    )
    profile_banner = models.ImageField(
        upload_to='banners/',
        null=True,
        blank=True,
        verbose_name="Баннер профиля",
    )
    phone = models.CharField(
        max_length=20,
        blank=True,
        default='',
        verbose_name="Телефон",
    )
    birthday = models.DateField(
        null=True,
        blank=True,
        verbose_name="День рождения",
    )
    bio = models.TextField(
        blank=True,
        default='',
        verbose_name="О себе",
    )

    class Meta:
        verbose_name = "Пользователь"
        verbose_name_plural = "Пользователи"
        unique_together = ['email', 'company']

    def __str__(self):
        company_name = self.company.name if self.company else "Без компании"
        return f"{self.email or self.username} ({self.get_role_display()}) - {company_name}"
