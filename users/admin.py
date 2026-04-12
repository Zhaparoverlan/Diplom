from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User
from django.utils.translation import gettext_lazy as _

class CustomUserAdmin(UserAdmin):
    model = User
    # Добавляем компанию и роль в список пользователей
    list_display = ['username', 'email', 'role', 'company', 'is_staff']
    list_filter = ['role', 'company', 'is_staff']
    
    # Добавляем поля в формы редактирования
    fieldsets = UserAdmin.fieldsets + (
        (_('Дополнительная информация'), {'fields': ('role', 'company')}),
    )
    add_fieldsets = UserAdmin.add_fieldsets + (
        (_('Дополнительная информация'), {'fields': ('role', 'company')}),
    )

admin.site.register(User, CustomUserAdmin)