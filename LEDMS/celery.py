import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'LEDMS.settings')

app = Celery('LEDMS')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()
