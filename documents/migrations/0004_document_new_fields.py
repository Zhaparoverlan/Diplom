from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('documents', '0003_alter_document_category_document_owner_and_more'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        # ── status: replace draft/pending/approved with the new five-value set ──
        migrations.AlterField(
            model_name='document',
            name='status',
            field=models.CharField(
                choices=[
                    ('pending',            'Ожидает обработки'),
                    ('ready',              'Готов'),
                    ('duplicate',          'Дубликат'),
                    ('needs_verification', 'Требует проверки'),
                    ('needs_approval',     'Ожидает одобрения'),
                ],
                default='pending',
                max_length=20,
                verbose_name='Статус',
            ),
        ),
        # ── amount: add null=True (was non-nullable with default 0.00) ─────────
        migrations.AlterField(
            model_name='document',
            name='amount',
            field=models.DecimalField(
                blank=True,
                decimal_places=2,
                max_digits=10,
                null=True,
                verbose_name='Сумма',
            ),
        ),
        # ── category: add null=True ───────────────────────────────────────────
        migrations.AlterField(
            model_name='document',
            name='category',
            field=models.CharField(
                blank=True,
                choices=[
                    ('purchase', 'Закуп'),
                    ('rent', 'Аренда'),
                    ('salary', 'Зарплата'),
                    ('utility', 'Коммуналка'),
                    ('other', 'Прочее'),
                ],
                default='other',
                max_length=20,
                null=True,
                verbose_name='Категория',
            ),
        ),
        # ── new fields ────────────────────────────────────────────────────────
        migrations.AddField(
            model_name='document',
            name='confidence_score',
            field=models.FloatField(blank=True, null=True, verbose_name='Уверенность OCR'),
        ),
        migrations.AddField(
            model_name='document',
            name='phash',
            field=models.CharField(
                blank=True, max_length=64, null=True, verbose_name='Перцептивный хэш',
            ),
        ),
        migrations.AddField(
            model_name='document',
            name='last_modified_by',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='modified_documents',
                to=settings.AUTH_USER_MODEL,
                verbose_name='Последнее изменение',
            ),
        ),
    ]
