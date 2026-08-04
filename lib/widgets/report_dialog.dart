import 'package:flutter/material.dart';
import 'package:npo_community/core/services/report_service.dart';

Future<void> showReportDialog({
  required BuildContext context,
  required ReportRequest baseRequest,
}) async {
  final outerContext = context;
  final detailsController = TextEditingController(
    text: baseRequest.details ?? '',
  );

  final reasons = <String>[
    'Harassment or bullying',
    'Hate speech',
    'Spam',
    'Sexual content',
    'Threats or violence',
    'Self-harm concern',
    'Other',
  ];

  String selectedReason = baseRequest.reason.isNotEmpty
      ? baseRequest.reason
      : reasons.first;
  bool submitting = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: !submitting,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogInnerContext, setState) {
          return AlertDialog(
            title: const Text('Report content'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: reasons
                      .map(
                        (r) =>
                            DropdownMenuItem<String>(value: r, child: Text(r)),
                      )
                      .toList(),
                  onChanged: submitting
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() {
                            selectedReason = v;
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Details (optional)',
                    hintText: 'Add any context that might help moderators.',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: submitting
                    ? null
                    : () async {
                        setState(() {
                          submitting = true;
                        });
                        try {
                          final request = ReportRequest(
                            type: baseRequest.type,
                            reason: selectedReason,
                            details: detailsController.text.trim().isEmpty
                                ? null
                                : detailsController.text.trim(),
                            targetId: baseRequest.targetId,
                            targetUserId: baseRequest.targetUserId,
                            targetUsername: baseRequest.targetUsername,
                            targetUrl: baseRequest.targetUrl,
                          );

                          await ReportService().submitReport(request);

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }

                          if (outerContext.mounted) {
                            ScaffoldMessenger.of(outerContext).showSnackBar(
                              const SnackBar(
                                content: Text('Report sent to moderators.'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (outerContext.mounted) {
                            ScaffoldMessenger.of(outerContext).showSnackBar(
                              SnackBar(
                                content: Text('Failed to send report: $e'),
                              ),
                            );
                          }
                        } finally {
                          if (dialogInnerContext.mounted) {
                            setState(() {
                              submitting = false;
                            });
                          }
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send'),
              ),
            ],
          );
        },
      );
    },
  );
}
