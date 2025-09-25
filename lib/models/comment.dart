// DO NOT CHANGE THIS FILE ANY CHANGE NEEDS A CORROSPONDING API CHANGE DONE BY PAIGE

class Comment {
  final int id;
  final String? user;
  final int? post;
  final String content;
  final String pubDate;

  Comment(
      {required this.id,
      this.user,
      this.post,
      required this.content,
      required this.pubDate});

  factory Comment.fromJson(Map<String, dynamic> json) {
    // Robustly parse the user, which may be an int (ID) or String (username)
    final dynamic userValue = json['user'];
    String? userString;
    if (userValue is int) {
      userString = userValue.toString(); // Convert int ID to string for display
    } else if (userValue is String) {
      userString = userValue;
    }

    // Robustly parse the post ID
    final dynamic postValue = json['post'];
    int? postId;
    if (postValue is int) {
      postId = postValue;
    } else if (postValue is String) {
      postId = int.tryParse(postValue);
    }

    return Comment(
      id: json['id'] as int,
      user: userString,
      post: postId,
      content: json['content'] as String,
      pubDate: json['pub_date'] as String,
    );
  }
}