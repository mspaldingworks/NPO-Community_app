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
  Future<void> submitReport(ReportRequest request) async {
    throw StateError(
      'Reporting is unavailable until server moderation is configured.',
    );
  }
}
