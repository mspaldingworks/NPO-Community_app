// DO NOT CHANGE THIS FILE ANY CHANGE NEEDS A CORROSPONDING API CHANGE DONE BY PAIGE

class Comment {
  final int id;
  final String content;
  final int authorId;
  final String authorUsername;
  final String? authorProfilePic;
  final bool authorIsStaff;
  final String pubDate;
  final String? updatedAt;
  final int postId;
  // TODO(paige-working): Uncomment when backend provides unread metadata.
  // final bool isUnreadForOwner;
  // final bool mentionsOwner;
  // final DateTime? createdAt;

  Comment({
    required this.id,
    required this.content,
    required this.authorId,
    required this.authorUsername,
    this.authorProfilePic,
    this.authorIsStaff = false,
    required this.pubDate,
    this.updatedAt,
    required this.postId,
    // this.isUnreadForOwner = false,
    // this.mentionsOwner = false,
    // this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    // The API sends 'user' as a string for the username.
    // The other author fields (id, profile_pic, is_staff) might be missing.
    // We will parse what's available and use defaults for the rest.
    final authorUsername =
        json['user'] as String? ??
        json['author_username'] as String? ??
        'Anonymous';
    final authorId =
        json['author_id'] as int? ??
        json['author'] as int? ??
        0; // Default to 0 if missing

    // TODO(paige-working): Uncomment when backend provides unread metadata.
    // final bool isUnreadForOwner = json['is_unread_for_owner'] as bool? ?? false;
    // final bool mentionsOwner = json['mentions_owner'] as bool? ?? false;
    // DateTime? createdAt;
    // final dynamic createdRaw = json['comment_created_at'] ?? json['created_at'];
    // if (createdRaw is String && createdRaw.isNotEmpty) {
    //   try {
    //     createdAt = DateTime.parse(createdRaw).toLocal();
    //   } catch (_) {
    //     createdAt = null;
    //   }
    // }

    return Comment(
      id: json['id'] as int,
      content: json['content'] as String,
      authorId: authorId,
      authorUsername: authorUsername,
      authorProfilePic: json['author_profile_pic'] as String?,
      authorIsStaff: json['author_is_staff'] as bool? ?? false,
      pubDate: json['pub_date'] as String,
      updatedAt:
          json['updated_at'] as String? ??
          json['modified_at'] as String? ??
          json['edited_at'] as String?,
      postId: json['post'] as int,
      // isUnreadForOwner: isUnreadForOwner,
      // mentionsOwner: mentionsOwner,
      // createdAt: createdAt,
    );
  }

  bool get isEdited =>
      updatedAt != null && updatedAt!.isNotEmpty && updatedAt != pubDate;
}
