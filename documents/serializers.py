from rest_framework import serializers
from .models import Document


class DocumentSerializer(serializers.ModelSerializer):
    author_name      = serializers.CharField(source='author.username',      read_only=True)
    status_display   = serializers.CharField(source='get_status_display',   read_only=True)
    category_display = serializers.CharField(source='get_category_display', read_only=True)

    class Meta:
        model  = Document
        fields = [
            'id', 'title', 'file',
            'supplier', 'amount', 'doc_date',
            'category', 'category_display',
            'status', 'status_display',
            'author', 'author_name',
            'raw_text', 'confidence_score',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'author', 'company',
            'status',
            'raw_text', 'confidence_score',
            'phash',
        ]
