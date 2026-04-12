from rest_framework import serializers
from .models import Document

class DocumentSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.username', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    category_display = serializers.CharField(source='get_category_display', read_only=True)

    class Meta:
        model = Document
        fields = [
            'id', 'title', 'file', 'supplier', 'amount', 
            'doc_date', 'category', 'category_display', 
            'status', 'status_display', 'author_name', 'created_at'
        ]
        # Эти поля клиент (Flutter) не присылает, мы ставим их сами
        read_only_fields = ['status', 'author', 'company', 'raw_text']