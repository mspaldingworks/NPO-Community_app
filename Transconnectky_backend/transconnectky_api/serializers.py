# myapp/serializers.py
from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import Resource, Group, Post, Comment, Message, PostImage
from taggit.serializers import TaggitSerializer, TaggitSerializerField
User = get_user_model()

class UserRegisterSerializer(serializers.ModelSerializer):
    
    password = serializers.CharField(write_only=True, required=True)
    password2 = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = User
        fields = (
            'username', 
            'email',
            'password', 
            'password2',
            'city',
            'status_message',
            'flair'
            )
        extra_kwargs = {
            'password': {'write_only': True}
        }

    def validate(self, data):
        if data['password'] != data['password2']:
            raise serializers.ValidationError({"password": "Password fields didn't match."})
        return data

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            city=validated_data['city'],
            status_message=validated_data['status_message'],
            flair=validated_data['flair']
        )
        return user

class UserUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = (
            'username', 
            'email', 
            'city',
            'status_message',
            'flair',
            'profile_pic',
            )
        read_only_fields = ('username',) # Optional: make username read-only after creation

    def __init__(self, *args, **kwargs):
        # Call the super constructor
        super().__init__(*args, **kwargs)
        # Make all fields optional for partial updates
        for field_name, field in self.fields.items():
            field.required = False

    def validate_email(self, value):
        # Optional: Add validation to ensure email is unique if it's being updated
        # This will prevent users from setting an email that already exists for another user.
        if self.instance and self.instance.email == value:
            return value # Email not changed, no need to validate uniqueness against itself

        if User.objects.filter(email=value).exclude(id=self.instance.id if self.instance else None).exists():
            raise serializers.ValidationError("This email is already in use by another account.")
        return value

    def update(self, instance, validated_data):
        # The default ModelSerializer update method handles updating fields
        # that are present in validated_data. No need for manual field updates.
        return super().update(instance, validated_data)

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'city', 'status_message', 'flair', 'profile_pic')

class ResourceSerializer(TaggitSerializer, serializers.ModelSerializer): # <-- Inherit from TaggitSerializer
    user = serializers.ReadOnlyField(source='user.username')
    
    # Use TaggitSerializerField to make tags writable
    tags = TaggitSerializerField() # <-- This is the main fix

    average_rating = serializers.FloatField(read_only=True)
    rating_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Resource
        fields = (
            'id', 'user', 'name', 'type', 'url', 'pub_date', 'public',
            'description', 'provider', 'tags', 'average_rating', 'rating_count'
        )
        read_only_fields = ('user', 'pub_date', 'average_rating', 'rating_count')

    # The get_tags method is no longer needed and should be removed.
class CommentSerializer(serializers.ModelSerializer):
    # Display username instead of user ID for the 'user' field
    user = serializers.ReadOnlyField(source='user.username')
    post_name = serializers.CharField(source='post.title', read_only=True)
    image = serializers.ImageField(write_only=True, required=False)
    image_url = serializers.SerializerMethodField()

    # Allow setting post by ID (writable)
    post = serializers.PrimaryKeyRelatedField(queryset=Post.objects.all())

    class Meta:
        model = Comment
        fields = ('id', 'user', 'post', 'post_name', 'content', 'pub_date', 'image', 'image_url')
        # 'user' and 'pub_date' are set automatically by the view/model
        # 'group_name' is read-only because it's a derived field
        read_only_fields = ('user', 'pub_date')

    def create(self, validated_data):
        # The 'user' field is automatically set to the requesting user in the view,
        # so we don't need to handle it here unless you want more complex logic.
        # Ensure that the 'group' object is correctly passed if using PrimaryKeyRelatedField
        return Comment.objects.create(**validated_data)

    def get_image_url(self, obj):
        request = self.context.get('request')
        try:
            return request.build_absolute_uri(obj.image.url) if obj.image else None
        except Exception:
            return None
        
class PostSerializer(serializers.ModelSerializer):
    # Display username instead of user ID for the 'user' field
    user = serializers.ReadOnlyField(source='user.username')

    # Option 1: Display group name (read-only)
    # This is suitable if you want to display the group name in GET requests,
    # but for POST/PUT, you'll need to send the group ID.
    group_name = serializers.CharField(source='group.name', read_only=True)

    # Option 2: Allow setting group by ID (writable)
    # This is often what you need for POST/PUT requests where you provide the group's ID.
    group = serializers.PrimaryKeyRelatedField(queryset=Group.objects.all())
    comments = CommentSerializer(many=True, read_only=True)

    class PostImageSerializer(serializers.ModelSerializer):
        url = serializers.SerializerMethodField()

        class Meta:
            model = PostImage
            fields = ['id', 'url']

        def get_url(self, obj):
            request = self.context.get('request')
            try:
                return request.build_absolute_uri(obj.image.url)
            except Exception:
                return None

    images = PostImageSerializer(many=True, read_only=True)

    class Meta:
        model = Post
        fields = ('id', 'user', 'group', 'group_name', 'title', 'body', 'emoji', 'feeling', 'pub_date', 'public', 'comments', 'images')
        # 'user' and 'pub_date' are set automatically by the view/model
        # 'group_name' is read-only because it's a derived field
        read_only_fields = ('user', 'pub_date', 'group_name')

    def create(self, validated_data):
        # The 'user' field is automatically set to the requesting user in the view,
        # so we don't need to handle it here unless you want more complex logic.
        # Ensure that the 'group' object is correctly passed if using PrimaryKeyRelatedField
        return Post.objects.create(**validated_data)

class GroupSerializer(serializers.ModelSerializer):
    class Meta:
        model = Group
        fields = ['id', 'name', 'description', 'avatarUrl']

class MessageSerializer(serializers.ModelSerializer):
    """
    Serializer for the Message model.
    """
    # Use a nested serializer to represent the sender and recipient
    sender = serializers.SerializerMethodField()
    recipient = serializers.SerializerMethodField()
    image = serializers.ImageField(write_only=True, required=False)
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ['id', 'sender', 'recipient', 'content', 'timestamp', 'is_read', 'image', 'image_url']
        read_only_fields = ['id', 'sender', 'timestamp', 'is_read']

    def get_sender(self, obj):
        return {
            'id': obj.sender.id,
            'username': obj.sender.username
        }

    def get_recipient(self, obj):
        return {
            'id': obj.recipient.id,
            'username': obj.recipient.username
        }

    def get_image_url(self, obj):
        request = self.context.get('request')
        try:
            return request.build_absolute_uri(obj.image.url) if obj.image else None
        except Exception:
            return None
