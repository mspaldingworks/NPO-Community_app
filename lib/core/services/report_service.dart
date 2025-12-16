import 'package:flutter/foundation.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/chat_service.dart';

enum ReportTargetType {
  post,
  comment,
  status,
  statusComment,
  resource,
  resourceReview,
  photo,
  user,
}

class ReportRequest {
  final ReportTargetType type;
  final String reason;
  final String? details;
  final int? targetId;
  final int? targetUserId;
  final String? targetUsername;
  final String? targetUrl;

  const ReportRequest({
    required this.type,
    required this.reason,
    this.details,
    this.targetId,
    this.targetUserId,
    this.targetUsername,
    this.targetUrl,
  });
}

class ReportService {
  ReportService({AuthService? authService, ChatService? chatService})
      : _authService = authService ?? AuthService(),
        _chatService = chatService ?? ChatService();

  final AuthService _authService;
  final ChatService _chatService;

  static const List<String> _adminUsernames = <String>[
    'Mad.E',
    'Mad.E.Made',
    'pmaxwell',
  ];

  Future<void> submitReport(ReportRequest request) async {
    final me = _authService.currentUser;
    final reporterUsername = me?.username ?? 'Unknown';

    final allUsers = await _authService.getAllUsers();
    final adminUsers = allUsers.where((u) => _adminUsernames.contains(u.username)).toList();

    if (adminUsers.isEmpty) {
      throw Exception('No admin recipients available.');
    }

    final String targetLine;
    if (request.type == ReportTargetType.user) {
      targetLine = 'userId=${request.targetUserId ?? 'unknown'} username=${request.targetUsername ?? 'unknown'}';
    } else {
      final userIdPart = request.targetUserId != null ? ' userId=${request.targetUserId}' : '';
      targetLine = 'id=${request.targetId ?? 'unknown'}$userIdPart username=${request.targetUsername ?? 'unknown'} url=${request.targetUrl ?? ''}';
    }

    final message = StringBuffer()
      ..writeln('[REPORT]')
      ..writeln('Reporter: $reporterUsername')
      ..writeln('Type: ${describeEnum(request.type)}')
      ..writeln('Target: $targetLine')
      ..writeln('Reason: ${request.reason}')
      ..writeln('Details: ${(request.details ?? '').trim()}');

    for (final admin in adminUsers) {
      await _chatService.sendMessage(recipientId: admin.id, content: message.toString());
    }
  }
}
