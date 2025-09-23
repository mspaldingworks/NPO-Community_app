from django.db import models
from django.contrib.auth.models import AbstractUser
from django.db.models import Avg, Count
from taggit.managers import TaggableManager
from django.conf import settings

class CustomUser(AbstractUser):
    # Define the choices for the user type
    USER_TYPE_CHOICES = (
        ("user", "User"),
        ("org", "Organization"),
        ("admin", "Admin"),
    )

    # Add your custom fields here
    city = models.CharField(max_length=200)
    status_message = models.CharField(max_length=128, blank=True, null=True)
    flair = models.CharField(max_length=200, blank=True, null=True)
    profile_pic = models.ImageField(upload_to='post_images/', blank=True, null=True)
    
    # Add the user_type field
    user_type = models.CharField(
        max_length=20, 
        choices=USER_TYPE_CHOICES, 
        default="user",
        help_text="The type of user (e.g., 'user', 'org', 'admin')"
    )

    def __str__(self):
        return self.username
    
class Resource(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='resources')
    name = models.CharField(max_length=200)
    type = models.CharField(max_length=200)
    url = models.CharField(max_length=200)
    pub_date = models.DateTimeField("date published", auto_now_add=True)
    public = models.BooleanField(default=False)
    
    # New Fields
    description = models.TextField(blank=True)
    provider = models.CharField(max_length=200, blank=True)
    tags = TaggableManager() # For filtering
    
    def __str__(self):
        return f"{self.name} ({self.user.username})"

    class Meta:
        ordering = ['-pub_date']

class ResourceRating(models.Model):
    resource = models.ForeignKey(Resource, on_delete=models.CASCADE, related_name='ratings')
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    rating = models.IntegerField(choices=[(i, i) for i in range(1, 6)]) # 1-5 star rating
    
    class Meta:
        unique_together = ('resource', 'user') # One rating per user per resource

class Group(models.Model):
    name = models.CharField(max_length=200, blank=True, null=True)
    description = models.CharField(max_length=200, blank=True, null=True)
    avatarUrl = models.CharField(max_length=200, blank=True, null=True)
    def __str__(self):
        return self.name

class Post(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    group = models.ForeignKey(Group, on_delete=models.CASCADE)
    title = models.CharField(max_length=200)
    body = models.CharField(max_length=200)
    emoji  = models.CharField(max_length=10, blank=True, null=True) 
    # image = models.ImageField()
    feeling  = models.CharField(max_length=128)
    pub_date = models.DateTimeField("date published", auto_now_add=True) # auto_now_add for creation time
    public = models.BooleanField(default=False) # Default to false for privacy
    
    def __str__(self):
        return f"{self.title} ({self.user.username})"

    class Meta:
        ordering = ['-pub_date'] # Order by most recent first

class FeaturedPost(models.Model):
    post = models.ForeignKey(Post, on_delete=models.CASCADE)

class Comment(models.Model):
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='comments')
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    content = models.TextField(blank=True, null=True) # Changed to TextField for long comments
    pub_date = models.DateTimeField("date published", auto_now_add=True)
    def __str__(self):
        return f"{self.content} ({self.user.username})"

class Reaction(models.Model):
    type = models.CharField(max_length=32)
    post = models.ForeignKey(Post, on_delete=models.CASCADE)

class Message(models.Model):
    """
    Represents a message sent between two users.
    """
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sent_messages',
        help_text="The user who sent the message."
    )
    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='received_messages',
        help_text="The user who received the message."
    )
    content = models.TextField(
        help_text="The content of the message."
    )
    timestamp = models.DateTimeField(
        auto_now_add=True,
        help_text="The date and time the message was sent."
    )
    is_read = models.BooleanField(
        default=False,
        help_text="Indicates whether the recipient has read the message."
    )

    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        return f"Message from {self.sender.username} to {self.recipient.username}"
