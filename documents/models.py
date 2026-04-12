from django.db import models
from django.conf import settings
from django.utils.translation import gettext_lazy as _

class Document(models.Model):  # Проверь, что название класса написано без ошибок
    # Категории
    CATEGORIES = (
        ('rent', _('Аренда')),
        ('purchase', _('Закуп')),
        ('salary', _('Зарплата')),
        ('other', _('Прочее')),
    )

    # Статусы
    STATUSES = (
        ('draft', _('Черновик')),
        ('pending', _('На проверке')),
        ('approved', _('Одобрено')),
        ('rejected', _('Отклонено')),
    )

    title = models.CharField(_("Название"), max_length=255)
    file = models.FileField(_("Файл/Фото"), upload_to='documents/%Y/%m/%d/')
    
    supplier = models.CharField(_("Поставщик"), max_length=255, blank=True, null=True)
    amount = models.DecimalField(_("Сумма"), max_digits=10, decimal_places=2, default=0.00)
    doc_date = models.DateField(_("Дата документа"), blank=True, null=True)
    category = models.CharField(_("Категория"), max_length=20, choices=CATEGORIES, default='other')
    
    status = models.CharField(_("Статус"), max_length=20, choices=STATUSES, default='draft')
    
    # ССЫЛКИ НА ДРУГИЕ МОДЕЛИ (ОБЯЗАТЕЛЬНО СТРОКАМИ!)
    company = models.ForeignKey(
        'company.Company', 
        on_delete=models.CASCADE, 
        related_name='documents',
        verbose_name=_("Компания")
    )
    
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name='my_documents',
        verbose_name=_("Автор")
    )

    raw_text = models.TextField(_("Распознанный текст"), blank=True, null=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _("Документ")
        verbose_name_plural = _("Документы")

    def __str__(self):
        return f"{self.title} ({self.company.name})"