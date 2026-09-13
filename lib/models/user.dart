import 'package:npo_community/core/constants/api_endpoints.dart';

class User {
  final int id;
  final String username;
  final String email;
  final String? city;
  final String? statusMessage;
  final DateTime? statusUpdatedAt;
  final String? flair;
  final String? profilePic;
  final List<Friend> friends;
  final String? userType;
  final bool isStaff;
  final bool isSuperuser;
  final int? programYear;
  final String? fullName;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.city,
    this.statusMessage,
    this.statusUpdatedAt,
    this.flair,
    this.profilePic,
    this.friends = const [],
    this.userType,
    this.isStaff = false,
    this.isSuperuser = false,
    this.programYear,
    this.fullName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Robustly parse the id, which may be an int or a string representation of an int.
    final dynamic idValue = json['id'];
    int parsedId;
    if (idValue is int) {
      parsedId = idValue;
    } else if (idValue is String) {
      parsedId = int.parse(idValue);
    } else {
      throw const FormatException('Invalid ID format');
    }

    // Safely handle the 'friends' list
    final friendsData = json['friends'] as List?;
    final friendsList = friendsData != null
        ? friendsData.map((friendJson) => Friend.fromJson(friendJson)).toList()
        : <Friend>[];

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) {
        try {
          return DateTime.parse(v).toLocal();
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return User(
      id: parsedId,
      username: json['username'] as String,
      email: json['email'] as String? ?? '',
      city: json['city'] as String?,
      statusMessage: json['status_message'] as String?,
      statusUpdatedAt: parseDate(
        json['status_updated_at'] ??
            json['statusUpdatedAt'] ??
            json['status_updated'] ??
            json['status_time'] ??
            json['status_at'] ??
            json['updated_at'],
      ),
      flair: json['flair'] as String?,
      profilePic: json['profile_pic'] as String?,
      friends: friendsList,
      userType: json['user_type'] as String?,
      isStaff: json['is_staff'] as bool? ?? false,
      isSuperuser: json['is_superuser'] as bool? ?? false,
      programYear: json['program_year'] as int?,
      fullName: json['full_name'] as String?,
    );
  }

  String? get fullProfilePicUrl {
    if (profilePic == null) return null;
    // Check if the API accidently sent a full URL, otherwise append host
    if (profilePic!.startsWith('http')) return profilePic;
    return ApiEndpoints.host + (profilePic ?? "");
  }
}

class Friend {
  final int id;
  final String username;
  final String email;
  final String? city;
  final String? statusMessage;
  final DateTime? statusUpdatedAt;
  final String? flair;
  final String? profilePic;

  Friend({
    required this.id,
    required this.username,
    required this.email,
    this.city,
    this.statusMessage,
    this.statusUpdatedAt,
    this.flair,
    this.profilePic,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    // Robustly parse the id, which may be an int or a string representation of an int.
    final dynamic idValue = json['id'];
    int parsedId;
    if (idValue is int) {
      parsedId = idValue;
    } else if (idValue is String) {
      parsedId = int.parse(idValue);
    } else {
      throw const FormatException('Invalid ID format');
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) {
        try {
          return DateTime.parse(v).toLocal();
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return Friend(
      id: parsedId,
      username: json['username'] as String,
      email: json['email'] as String? ?? '', // Handle missing email gracefully
      city: json['city'] as String?,
      statusMessage: json['status_message'] as String?,
      statusUpdatedAt: parseDate(
        json['status_updated_at'] ??
            json['statusUpdatedAt'] ??
            json['status_updated'] ??
            json['status_time'] ??
            json['status_at'] ??
            json['updated_at'],
      ),
      flair: json['flair'] as String?,
      profilePic: json['profile_pic'] as String?,
    );
  }

  String? get fullProfilePicUrl {
    if (profilePic == null) return null;
    // If backend returns full URL, use it as-is
    if (profilePic!.startsWith('http')) return profilePic;
    // If backend returns a path that already begins with '/media', just prefix host
    if (profilePic!.startsWith('/')) return ApiEndpoints.host + profilePic!;
    // Otherwise assume it's a relative path under /media
    return '${ApiEndpoints.host}/media/${profilePic!}';
  }
}
