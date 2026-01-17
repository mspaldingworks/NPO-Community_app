class MeadowChatComment {
  const MeadowChatComment({
    required this.id,
    required this.chatId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String chatId;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;
}
