from rest_framework import serializers
from .models import User
from company.models import Company


class UserSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source='company.name', read_only=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'role', 'company', 'company_name']


class RegisterCompanySerializer(serializers.Serializer):
    company_name = serializers.CharField(max_length=255)
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def create(self, validated_data):
        company = Company.objects.create(name=validated_data['company_name'])
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            company=company,
            role=User.OWNER,
        )
        return user


class UserProfileSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source='company.name', read_only=True)
    role_display = serializers.CharField(source='get_role_display', read_only=True)
    full_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'username', 'full_name', 'first_name', 'last_name',
            'email', 'phone', 'birthday', 'bio',
            'avatar', 'profile_banner',
            'role', 'role_display', 'company', 'company_name', 'date_joined',
        ]
        read_only_fields = [
            'id', 'username', 'role', 'company', 'company_name',
            'role_display', 'date_joined', 'full_name',
        ]

    def get_full_name(self, obj):
        return f"{obj.first_name} {obj.last_name}".strip() or obj.username

    def update(self, instance, validated_data):
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        return instance


class EmployeeCreateSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ['first_name', 'last_name', 'email', 'password', 'role']

    def create(self, validated_data):
        password = validated_data.pop('password')
        email = validated_data.get('email', '')
        user = User.objects.create_user(
            username=email,
            password=password,
            **validated_data,
        )
        return user


class EmployeeUpdateSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=False, min_length=8)

    class Meta:
        model = User
        fields = ['email', 'first_name', 'last_name', 'role', 'password']

    def update(self, instance, validated_data):
        password = validated_data.pop('password', None)
        if 'email' in validated_data:
            instance.username = validated_data['email']
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if password:
            instance.set_password(password)
        instance.save()
        return instance


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True, write_only=True)
    new_password = serializers.CharField(required=True, write_only=True, min_length=8)
    confirm_password = serializers.CharField(required=True, write_only=True)

    def validate(self, data):
        if data['new_password'] != data['confirm_password']:
            raise serializers.ValidationError({"confirm_password": "Пароли не совпадают."})
        return data
