import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/core/services/report_service.dart';

void main() {
  test('reports fail closed until server moderation is configured', () async {
    const request = ReportRequest(
      type: ReportTargetType.post,
      reason: 'Safety concern',
      targetId: 42,
    );

    await expectLater(
      ReportService().submitReport(request),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('server moderation'),
        ),
      ),
    );
  });
}
