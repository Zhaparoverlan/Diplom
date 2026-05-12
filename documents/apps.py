import os

from django.apps import AppConfig


class DocumentsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'documents'

    def ready(self):
        # Раньше импорта paddle: снижает риск oneDNN+PIR NotImplementedError на CPU (Windows).
        os.environ.setdefault("FLAGS_use_mkldnn", "0")
