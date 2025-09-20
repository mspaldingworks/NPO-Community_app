class User {
  final int id;
  final String username;
  final String email;
  final String? city;
  final String? statusMessage;
  final String? flair;
  final String? profilePic;
  final String token;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.city,
    this.statusMessage,
    this.flair,
    this.profilePic,
    required this.token,
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

    return User(
      id: parsedId,
      username: json['username'] as String,
      email: json['email'] as String,
      city: json['city'] as String?,
      statusMessage: json['status_message'] as String?,
      flair: json['flair'] as String?,
      profilePic: json['profile_pic'] as String?,
      token: json['token'] as String,
    );
  }
}
