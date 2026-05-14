from django.db import models
from django.conf import settings
from django.utils.translation import gettext_lazy as _


class Document(models.Model):
    CATEGORY_CHOICES = [
        ('purchase', 'Закуп'),
        ('rent', 'Аренда'),
        ('salary', 'Зарплата'),
        ('utility', 'Коммуналка'),
        ('other', 'Прочее'),
    ]

    STATUS_CHOICES = [
        ('pending',            'Ожидает обработки'),
        ('ready',              'Одобрен'),
        ('duplicate',          'Дубликат'),
        ('needs_verification', 'Требует проверки'),
        ('needs_approval',     'Ожидает одобрения'),
    ]

    title = models.CharField(_("Название"), max_length=255)
    file  = models.FileField(_("Файл/Фото"), upload_to='documents/%Y/%m/%d/')

    owner  = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        verbose_name="Владелец",
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='my_documents',
        verbose_name=_("Автор"),
    )
    last_modified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='modified_documents',
        verbose_name=_("Последнее изменение"),
    )
    company = models.ForeignKey(
        'company.Company',
        on_delete=models.CASCADE,
        related_name='documents',
        verbose_name=_("Компания"),
    )

    supplier = models.CharField(_("Поставщик"),   max_length=255, blank=True, null=True)
    amount   = models.DecimalField(_("Сумма"),     max_digits=10, decimal_places=2,
                                    null=True, blank=True)
    doc_date = models.DateField(_("Дата документа"), blank=True, null=True)
    category = models.CharField(_("Категория"),   max_length=20,
                                 choices=CATEGORY_CHOICES, default='other',
                                 null=True, blank=True)
    status   = models.CharField(_("Статус"),      max_length=20,
                                 choices=STATUS_CHOICES, default='pending')

    raw_text         = models.TextField(_("Распознанный текст"), blank=True, null=True)
    confidence_score = models.FloatField(_("Уверенность OCR"),   null=True, blank=True)
    phash            = models.CharField(_("Перцептивный хэш"),   max_length=64,
                                         blank=True, null=True)

    updated_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Создан")

    class Meta:
        verbose_name        = _("Документ")
        verbose_name_plural = _("Документы")

    def __str__(self):
        return f"{self.title} ({self.company.name})"
