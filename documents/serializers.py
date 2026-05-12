from rest_framework import serializers
from .models import Document

class DocumentSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.username', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    ocr_confidence = serializers.SerializerMethodField(read_only=True)

    def get_ocr_confidence(self, obj):
        return getattr(obj, "_ocr_confidence", None)

    class Meta:
        model = Document
        fields = [
            'id', 'title', 'file', 'supplier', 'amount',
            'doc_date', 'category', 'category_display',
            'status', 'status_display', 'author_name', 'created_at', 'author', 'raw_text',
            'ocr_confidence',
        ]
        # Эти поля клиент (Flutter) не присылает, мы ставим их сами
        read_only_fields = ['author', 'company', 'raw_text']