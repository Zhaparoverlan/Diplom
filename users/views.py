from rest_framework import generics, permissions, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import User
from .serializers import (
    ChangePasswordSerializer,
    EmployeeCreateSerializer,
    EmployeeUpdateSerializer,
    RegisterCompanySerializer,
    UserProfileSerializer,
)


class RegisterCompanyView(generics.CreateAPIView):
    serializer_class = RegisterCompanySerializer
    permission_classes = [AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(
                {"message": "Компания и владелец успешно созданы"},
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class UserMeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user

    def update(self, request, *args, **kwargs):
        kwargs['partial'] = True
        return super().update(request, *args, **kwargs)


class ChangePasswordView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        user = request.user
        if not user.check_password(serializer.validated_data['old_password']):
            return Response(
                {"old_password": "Текущий пароль неверен."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.set_password(serializer.validated_data['new_password'])
        user.save()
        return Response({"detail": "Пароль успешно изменён."}, status=status.HTTP_200_OK)


class EmployeeListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return EmployeeCreateSerializer
        return UserProfileSerializer

    def get_queryset(self):
        return User.objects.filter(company=self.request.user.company)

    def perform_create(self, serializer):
        requester = self.request.user
        if requester.role not in ('owner', 'manager'):
            raise PermissionDenied("Только Owner или Manager могут добавлять сотрудников.")

        role = serializer.validated_data.get('role', 'employee')
        if requester.role == 'manager' and role == 'owner':
            raise PermissionDenied("Менеджер не может создавать владельцев.")

        serializer.save(company=requester.company)


class UserDeleteAPIView(generics.DestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'id'

    def get_queryset(self):
        return User.objects.filter(company=self.request.user.company)

    def perform_destroy(self, instance):
        requester = self.request.user

        if instance.pk == requester.pk:
            raise PermissionDenied("Нельзя удалить самого себя.")

        if requester.role == 'owner':
            instance.delete()
        elif requester.role == 'manager':
            if instance.role in ('owner', 'manager'):
                raise PermissionDenied(
                    "Менеджер не может удалять владельцев или других менеджеров."
                )
            instance.delete()
        else:
            raise PermissionDenied("У вас нет прав на удаление пользователей.")


class EmployeeUpdateView(generics.UpdateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = EmployeeUpdateSerializer
    lookup_field = 'id'

    def get_queryset(self):
        return User.objects.filter(company=self.request.user.company)

    def update(self, request, *args, **kwargs):
        requester = request.user
        instance = self.get_object()

        if requester.role not in ('owner', 'manager'):
            raise PermissionDenied("Только Owner или Manager могут редактировать сотрудников.")

        if requester.role == 'manager':
            if instance.role in ('owner', 'manager'):
                raise PermissionDenied(
                    "Менеджер не может редактировать владельцев или других менеджеров."
                )
            if request.data.get('role') == 'owner':
                raise PermissionDenied("Менеджер не может назначить роль 'Владелец'.")

        kwargs['partial'] = True
        return super().update(request, *args, **kwargs)
