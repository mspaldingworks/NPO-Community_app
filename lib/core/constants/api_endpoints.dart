import 'package:npo_community/core/config/app_config.dart';

class ApiEndpoints {
  ApiEndpoints._();

  static String get host => AppConfig.current.apiOrigin.toString();
  static const String _base = '/api';

  // REST endpoints
  static const String conversations = '$_base/conversations/';
  static String conversation(String id) => '$_base/conversations/$id/';
  static String conversationMessages(String id) =>
      '$_base/conversations/$id/messages/';
  static String markAsRead(String id) => '$_base/conversations/$id/mark_read/';
  static String muteConversation(String id) => '$_base/conversations/$id/mute/';
  static String unmuteConversation(String id) =>
      '$_base/conversations/$id/unmute/';
  static String searchConversationMessages(String id) =>
      '$_base/conversations/$id/search/';

  // WebSocket endpoints
  static const String wsBase = '/ws';
  static String wsConversation(String id) => '$wsBase/chat/$id/';
}
