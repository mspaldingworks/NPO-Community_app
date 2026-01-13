import 'package:flutter/material.dart';
import 'package:transconnect/widgets/link_preview_card.dart';

class SmartLinkBody extends StatelessWidget {
  final String? text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool showText;
  final bool showPreview;
  final double? previewMaxWidth;
  final Alignment previewAlignment;

  const SmartLinkBody({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.showText = true,
    this.showPreview = true,
    this.previewMaxWidth,
    this.previewAlignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    final t = (text ?? '').trimRight();
    if (t.trim().isEmpty) return const SizedBox.shrink();

    Widget preview = LinkPreviewCard(urlOrText: t);
    if (previewMaxWidth != null) {
      preview = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: previewMaxWidth!),
        child: preview,
      );
    }

    preview = Align(
      alignment: previewAlignment,
      child: preview,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showText)
          Text(
            t,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
          ),
        if (showPreview) preview,
      ],
    );
  }
}
