import 'package:npo_community/core/services/api_client.dart';

/// What is being reported; `name` is the API's `target_type`.
enum ReportTargetType {
  post,
  comment,

  /// A direct message (`/api/messages/`).
  message,

  /// A conversation or group-chat message.
  chatMessage,
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

/// Sends reports to the moderators' queue (`POST /api/reports/`). Reporting
/// the same thing twice returns the report that is already open.
class ReportService extends ApiClient {
  ReportService();

  Future<void> submitReport(ReportRequest request) async {
    await post(
      urlPath: '/api/reports/',
      jsonHeaders: authHeaders,
      jsonPayload: {
        'target_type': request.type.name,
        'target_id': request.targetId?.toString() ?? '',
        'reason': request.reason,
        if (request.details != null) 'details': request.details,
        if (request.targetUserId != null)
          'target_user_id': request.targetUserId,
        if (request.targetUrl != null) 'target_url': request.targetUrl,
      },
      // 201 whether the report is new or one is already open (`created`).
      expectedStatusCode: 201,
    );
  }
}
