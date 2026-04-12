from django.db import models

class Company(models.Model):
    name = models.CharField("Название компании", max_length=255)
    address = models.TextField("Адрес", blank=True, null=True)
    inn = models.CharField("ИНН", max_length=14, unique=True, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name = "Компания"
        verbose_name_plural = "Компании"