import 'package:flutter/material.dart';
import 'package:npo_community/core/services/link_preview_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkPreviewCard extends StatefulWidget {
  final String? urlOrText;
  final Uri? url;

  const LinkPreviewCard({super.key, this.urlOrText, this.url});

  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  Uri? _resolved;
  Future<LinkPreviewMetadata?>? _future;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant LinkPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urlOrText != widget.urlOrText ||
        oldWidget.url != widget.url) {
      _resolve();
    }
  }

  void _resolve() {
    final uri =
        widget.url ?? LinkPreviewService().extractFirstUrl(widget.urlOrText);
    _resolved = uri;
    _future = uri == null ? null : LinkPreviewService().fetchMetadata(uri);
  }

  Future<void> _openUrl(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (ok) return;
    } catch (_) {}

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    final future = _future;

    if (resolved == null || future == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<LinkPreviewMetadata?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Loading preview…',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final metadata = snapshot.data;
        if (metadata == null) {
          return const SizedBox.shrink();
        }

        final title = metadata.title?.trim() ?? '';
        final description = metadata.description?.trim() ?? '';
        final siteName = metadata.siteName?.trim() ?? metadata.url.host;
        final image = metadata.imageUrl;

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black12),
            ),
            child: InkWell(
              onTap: () => _openUrl(metadata.url),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (image != null)
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: Image.network(
                        image.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.link, size: 20),
                          );
                        },
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            siteName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: Colors.grey.shade700),
                          ),
                          if (title.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
