# myapp/permissions.py
from rest_framework import permissions

class IsOwnerOrReadOnlyPublic(permissions.BasePermission):
    """
    Custom permission to only allow owners of an object to edit/delete it,
    and allow read access to public resources for any authenticated user,
    or read access to owned resources for the owner.
    """

    def has_permission(self, request, view):
        # Authenticated users can always create resources.
        # List view: Authenticated users can list their own + public resources.
        # Unauthenticated users can only see public resources in the list.
        if request.method in permissions.SAFE_METHODS:
            return True # Handled by get_queryset for list, and has_object_permission for retrieve.
        return request.user and request.user.is_authenticated

    def has_object_permission(self, request, view, obj):
        # Read permissions are allowed to any request for public resources,
        # or for the owner of the resource.
        if request.method in permissions.SAFE_METHODS:
            # If the resource is public, any authenticated user can view it.
            # If the user is the owner, they can view it regardless of public status.
            return obj.public or (request.user and request.user == obj.user)

        # Write permissions (PUT, PATCH, DELETE) are only allowed to the owner of the resource.
        return obj.user == request.user