from rest_framework import generics, permissions
from rest_framework.exceptions import PermissionDenied
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser

from .serializers import CompanySerializer


class CompanyDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = CompanySerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_object(self):
        return self.request.user.company

    def update(self, request, *args, **kwargs):
        if request.user.role != 'owner':
            raise PermissionDenied("Только владелец может изменять данные компании.")
        kwargs['partial'] = True
        return super().update(request, *args, **kwargs)
