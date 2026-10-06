import 'package:flutter/material.dart';
import 'package:npo_community/theme/app_theme.dart';

/// Widgets that mirror named components on ky.emergeamerica.org so the app
/// and the website read as one product. Each widget's doc comment names the
/// website CSS class it replicates; the colors and type come from
/// [AppColors] / the app theme, which are extracted from the same CSS.
/// See docs/design-system.md for the full token table.

/// The EMERGE KENTUCKY wordmark (same PNG the website serves in its nav).
class EmergeLogo extends StatelessWidget {
  const EmergeLogo({super.key, this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/emerge_ky_logo.png',
      width: width ?? 220,
      fit: BoxFit.contain,
      semanticLabel: 'Emerge Kentucky',
    );
  }
}

/// Color variants matching the website's flat button classes.
enum EmergeButtonVariant {
  /// `.button--blue` — teal `#217580`.
  teal,

  /// `.button--dark-green` — dark teal `#095256`.
  darkTeal,

  /// `.c-nav__donate-btn` — the green Contribute button.
  green,

  /// `.button--purple` — the periwinkle Sign Up button.
  periwinkle,

  /// `.button--orange`.
  orange,
}

/// A website-style call-to-action button: flat, square-cornered, uppercase
/// Montserrat 600 on a solid brand color (the shared `.button` rules).
class EmergeButton extends StatelessWidget {
  const EmergeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = EmergeButtonVariant.teal,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final EmergeButtonVariant variant;

  /// Fill the available width (the website's `.button--big`).
  final bool expanded;

  static const Map<EmergeButtonVariant, Color> _background = {
    EmergeButtonVariant.teal: Color(0xFF217580),
    EmergeButtonVariant.darkTeal: AppColors.primaryDark,
    EmergeButtonVariant.green: AppColors.green,
    EmergeButtonVariant.periwinkle: AppColors.periwinkle,
    EmergeButtonVariant.orange: AppColors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _background[variant],
        foregroundColor: AppColors.textWhite,
      ),
      onPressed: onPressed,
      child: Text(label.toUpperCase()),
    );
    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// The three green dots the website uses as a section divider
/// (`.c-quote__dots`: 14px circles, green, 10px apart).
class EmergeQuoteDots extends StatelessWidget {
  const EmergeQuoteDots({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (_) {
        return Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

/// A centered heading with optional summary text and the dots divider —
/// the website's `.c-title-block` + `.c-quote__dots` pattern (e.g. the
/// "All Alumnae: 334 Ready to Run" block).
class EmergeTitleBlock extends StatelessWidget {
  const EmergeTitleBlock({
    super.key,
    required this.title,
    this.summary,
    this.showDots = true,
  });

  final String title;
  final String? summary;
  final bool showDots;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Text(
            title,
            style: textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          if (summary != null) ...[
            const SizedBox(height: 8),
            Text(
              summary!,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          if (showDots) ...[
            const SizedBox(height: 16),
            const EmergeQuoteDots(),
          ],
        ],
      ),
    );
  }
}

/// A page-title band — the website's `.c-photo-header` (Montserrat title on
/// a photo or teal background) and `.c-text-header--green` (alumna pages).
class EmergePhotoHeader extends StatelessWidget {
  const EmergePhotoHeader({super.key, required this.title, this.image});

  final String title;

  /// Optional background image; without one the band is dark teal, matching
  /// the alumna-page text header.
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final onImage = image != null;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        image: onImage
            ? DecorationImage(
                image: image!,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.35),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 32,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: AppColors.textWhite,
        ),
      ),
    );
  }
}

/// One tile of the website's home quick-link grid (CALENDAR · RECENT NEWS ·
/// JOIN OUR MOVEMENT · FOLLOW US): an uppercase Montserrat label with a
/// trailing icon on a solid brand surface.
///
/// A [highlighted] tile swaps to the brand green with a soft glow, the way
/// Home flags something that needs the member's attention, and may carry a
/// small [badge] (a count) beside the icon.
class EmergeActionTile extends StatelessWidget {
  const EmergeActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.background = Colors.white,
    this.foreground = AppColors.primary,
    this.highlighted = false,
    this.badge,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;

  /// Lights the tile up in green with a glow.
  final bool highlighted;

  /// Short text (a count) shown in a pill beside the icon.
  final String? badge;

  static const Color highlightColor = AppColors.green;

  @override
  Widget build(BuildContext context) {
    final bg = highlighted ? highlightColor : background;
    final fg = highlighted ? AppColors.textWhite : foreground;
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: highlightColor.withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
      child: Material(
        color: bg,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: fg,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: fg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: bg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(icon, color: fg, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An alumna bio layout matching the website's `.c-bio-body`: portrait (or
/// initials) on the left, name in Emerge teal, the office or role as the
/// subtitle, body copy underneath.
class EmergeBioCard extends StatelessWidget {
  const EmergeBioCard({
    super.key,
    required this.name,
    this.subtitle,
    this.detail,
    this.image,
    this.initials,
  });

  final String name;

  /// e.g. the office held or sought (`.c-bio-body__subtitle`).
  final String? subtitle;

  /// e.g. county and cohort line, or a short bio.
  final String? detail;
  final ImageProvider? image;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFFDCF2F5),
            foregroundColor: AppColors.primaryDark,
            backgroundImage: image,
            child: image == null ? Text(initials ?? '?') : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                if (detail != null) ...[
                  const SizedBox(height: 6),
                  Text(detail!, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
