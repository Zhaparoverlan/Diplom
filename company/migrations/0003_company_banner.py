from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('company', '0002_company_logo'),
    ]

    operations = [
        migrations.AddField(
            model_name='company',
            name='banner',
            field=models.ImageField(
                blank=True,
                null=True,
                upload_to='company_banners/',
                verbose_name='Баннер',
            ),
        ),
    ]
