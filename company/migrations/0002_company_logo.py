from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('company', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='company',
            name='logo',
            field=models.ImageField(
                blank=True,
                null=True,
                upload_to='company_logos/',
                verbose_name='Логотип',
            ),
        ),
    ]
