import 'package:npo_community/core/constants/api_endpoints.dart';

/// A social media or other link on a member's profile, as the API stores it
/// in `links`: `{"label": "Instagram", "url": "https://..."}`.
class ProfileLink {
  const ProfileLink({required this.label, required this.url});

  final String label;
  final String url;

  /// The label, or the site's host when the member left the label blank.
  String get displayLabel {
    if (label.trim().isNotEmpty) return label.trim();
    final host = Uri.tryParse(url)?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  factory ProfileLink.fromJson(Map<String, dynamic> json) => ProfileLink(
    label: json['label'] as String? ?? '',
    url: json['url'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'label': label, 'url': url};

  static List<ProfileLink> listFromJson(dynamic rows) => [
    for (final row in (rows as List? ?? const []))
      if (row is Map<String, dynamic> &&
          (row['url'] as String? ?? '').isNotEmpty)
        ProfileLink.fromJson(row),
  ];

  @override
  bool operator ==(Object other) =>
      other is ProfileLink && other.label == label && other.url == url;

  @override
  int get hashCode => Object.hash(label, url);
}

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

  /// Staff, superusers and moderator/staff/admin role holders, as decided by
  /// the server (`can_moderate`); opens the moderation panel.
  final bool canModerate;

  /// Superusers and admin-role holders: opens the control console.
  final bool canAdmin;

  /// The server's verification tier key, e.g. 'unverified' or 'verified'.
  final String? verificationTier;
  final int? programYear;
  final String? fullName;

  /// How she'd like to help (keys of the API's VOLUNTEER_ROLES).
  final List<String> volunteerRoles;

  /// Social media and other links she shares on her profile.
  final List<ProfileLink> links;

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
    this.canModerate = false,
    this.canAdmin = false,
    this.verificationTier,
    this.programYear,
    this.fullName,
    this.volunteerRoles = const [],
    this.links = const [],
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
      canModerate:
          json['can_moderate'] as bool? ??
          ((json['is_staff'] as bool? ?? false) ||
              (json['is_superuser'] as bool? ?? false)),
      canAdmin:
          json['can_admin'] as bool? ??
          (json['is_superuser'] as bool? ?? false),
      verificationTier: json['verification_tier'] as String?,
      programYear: json['program_year'] as int?,
      fullName: json['full_name'] as String?,
      volunteerRoles: [
        for (final role in (json['volunteer_roles'] as List? ?? const []))
          if (role is String) role,
      ],
      links: ProfileLink.listFromJson(json['links']),
    );
  }

  /// A self-signup still waiting for a moderator to verify her (or link her
  /// to her alumnae roster record). Staff and superusers never wait.
  bool get isAwaitingVerification =>
      verificationTier == 'unverified' && !isStaff && !isSuperuser;

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
  final List<ProfileLink> links;

  Friend({
    required this.id,
    required this.username,
    required this.email,
    this.city,
    this.statusMessage,
    this.statusUpdatedAt,
    this.flair,
    this.profilePic,
    this.links = const [],
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
      links: ProfileLink.listFromJson(json['links']),
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
