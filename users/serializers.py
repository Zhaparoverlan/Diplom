from rest_framework import serializers
from .models import User
from company.models import Company

class UserSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source='company.name', read_only=True)

class Meta:
    model = User
    fields = ['id', 'username', 'email', 'first_name', 'last_name', 'role', 'company', 'company_name']


class RegisterCompanySerializer(serializers.Serializer):
    # Данные компании
    company_name = serializers.CharField(max_length=255)
    
    # Данные владельца
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def create(self, validated_data):
        # 1. Создаем компанию
        company = Company.objects.create(name=validated_data['company_name'])
        
        # 2. Создаем пользователя-владельца
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            company=company,
            role=User.OWNER  # Сразу ставим роль Владельца
        )
        return user