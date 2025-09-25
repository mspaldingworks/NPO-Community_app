class User {
  final int id;
  final String username;
  final String email;
  final String? city;
  final String? statusMessage;
  final String? flair;
  final String? profilePic;
  final String? token;
  final List<Friend> friends;
  final bool isStaff;
  final String userType;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.city,
    this.statusMessage,
    this.flair,
    this.profilePic,
    this.token,
    this.friends = const [],
    this.isStaff = false,
    this.userType = 'user',
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
      email: json['email'] as String,
      city: json['city'] as String?,
      statusMessage: json['status_message'] as String?,
      flair: json['flair'] as String?,
      profilePic: json['profile_pic'] as String?,
      token: json['token'] as String?,
      friends: friendsList,
      isStaff: json['is_staff'] as bool? ?? false,
      userType: json['user_type'] as String? ?? 'user',
    );
  }
}

class Friend {
  final int id;
  final String username;
  final String? city;
  final String? statusMessage;
  final String? flair;
  final String? profilePic;
  final String? token;

  Friend({
    required this.id,
    required this.username,
    this.city,
    this.statusMessage,
    this.flair,
    this.profilePic,
    this.token,
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
      city: json['city'] as String?,
      statusMessage: json['status_message'] as String?,
      flair: json['flair'] as String?,
      profilePic: json['profile_pic'] as String?,
      token: json['token'] as String?,
    );
  }
}
