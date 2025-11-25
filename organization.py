# transconnectky_api/organization.py

from rest_framework import serializers, viewsets, permissions
# Note: You may need to adjust the import path based on your project structure.
# This assumes your Organization model is in a 'models.py' file in the same app.
from .models import Organization

# =============================================================================
# Serializers
# =============================================================================

class OrganizationSerializer(serializers.ModelSerializer):
    """
    Serializer for the Organization model.
    This defines the JSON representation of an Organization.
    """
    # This field will show the username of the user who owns the organization.
    # It's read-only because it's set automatically on the backend.
    user = serializers.ReadOnlyField(source='user.username')

    class Meta:
        model = Organization
        # Define the fields to include in the API response.
        fields = [
            'id',
            'name',
            'description',
            'website',
            'phone_number',
            'user',  # The user associated with the organization
            'created_at',
            'updated_at',
        ]
        # Fields that should not be editable directly via the API.
        read_only_fields = ['user', 'created_at', 'updated_at']


# =============================================================================
# Views
# =============================================================================

class OrganizationViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows organizations to be viewed or edited.
    This handles GET, POST, PUT, DELETE requests for organizations.
    """
    queryset = Organization.objects.all().order_by('-created_at')
    serializer_class = OrganizationSerializer
    # Permissions can be adjusted. This example allows anyone to view,
    # but only authenticated users to create/edit.
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def perform_create(self, serializer):
        """
        Automatically associate the new organization with the user making the request.
        """
        serializer.save(user=self.request.user)
