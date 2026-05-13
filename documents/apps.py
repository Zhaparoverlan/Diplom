from django.apps import AppConfig


class DocumentsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'documents'

    def ready(self):
        # Eagerly load OCR weights at server startup so the first upload request
        # doesn't pay the cold-start penalty (~5-15 s of model initialisation).
        try:
            from .services import _get_ocr_engine
            _get_ocr_engine()
        except Exception:
            pass  # don't break startup if paddleocr is not installed
