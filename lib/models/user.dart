import 'package:transconnect/core/constants/api_endpoints.dart';

class User {
  final int id;
  final String username;
  final String email;
  final String? city;
  final String? statusMessage;
  final String? flair;
  final String? profilePic;
  final List<Friend> friends;
  final String? userType;
  final bool isStaff;
  final String? fullName;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.city,
    this.statusMessage,
    this.flair,
    this.profilePic,
    this.friends = const [],
    this.userType,
    this.isStaff = false,
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

    return User(
id: parsedId,
      username: json['username'] as String,
      email: json['email'] as String? ?? '',
      city: json['city'] as String?,
      statusMessage: json['status_message'] as String?,
      flair: json['flair'] as String?,
      profilePic: json['profile_pic'] as String?,
      friends: friendsList,
      userType: json['user_type'] as String?,
      isStaff: json['is_staff'] as bool? ?? false,
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
  final String? flair;
  final String? profilePic;

  Friend({
    required this.id,
    required this.username,
    required this.email,
    this.city,
    this.statusMessage,
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

    return Friend(
      id: parsedId,
      username: json['username'] as String,
      email: json['email'] as String? ?? '', // Handle missing email gracefully
      city: json['city'] as String?,
      statusMessage: json['status_message'] as String?,
      flair: json['flair'] as String?,
      profilePic: json['profile_pic'] as String?,
    );
  }

  String? get fullProfilePicUrl {
    if (profilePic == null) return null;
    // Check if the API accidently sent a full URL, otherwise append host
    if (profilePic!.startsWith('http')) return profilePic; 
    return ApiEndpoints.host + '/media/' + (profilePic ?? ""); // TODO Look into why friend profile pics do not add media folder
  }
}
