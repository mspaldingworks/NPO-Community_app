// DO NOT CHANGE THIS FILE ANY CHANGE NEEDS A CORROSPONDING API CHANGE DONE BY PAIGE

class Comment {
  final int id;
  final String content;
  final int authorId;
  final String authorUsername;
  final String? authorProfilePic;
  final bool authorIsStaff;
  final String pubDate;
  final int postId;

  Comment({
    required this.id,
    required this.content,
    required this.authorId,
    required this.authorUsername,
    this.authorProfilePic,
    this.authorIsStaff = false,
    required this.pubDate,
    required this.postId,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    // The API sends 'user' as a string for the username.
    // The other author fields (id, profile_pic, is_staff) might be missing.
    // We will parse what's available and use defaults for the rest.
    final authorUsername = json['user'] as String? ?? json['author_username'] as String? ?? 'Anonymous';
    final authorId = json['author_id'] as int? ?? json['author'] as int? ?? 0; // Default to 0 if missing

    return Comment(
      id: json['id'] as int,
      content: json['content'] as String,
      authorId: authorId,
      authorUsername: authorUsername,
      authorProfilePic: json['author_profile_pic'] as String?,
      authorIsStaff: json['author_is_staff'] as bool? ?? false,
      pubDate: json['pub_date'] as String,
      postId: json['post'] as int,
    );
  }
}