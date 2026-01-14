import 'dart:convert';

class OnboardingTourConfig {
  final WelcomeMessage? welcomeMessage;
  final List<TourStep> tour;
  final String? postTourTip;
  final String? revisitInstructions;

  const OnboardingTourConfig({
    required this.welcomeMessage,
    required this.tour,
    required this.postTourTip,
    required this.revisitInstructions,
  });

  static OnboardingTourConfig empty() {
    return const OnboardingTourConfig(
      welcomeMessage: null,
      tour: <TourStep>[],
      postTourTip: null,
      revisitInstructions: null,
    );
  }

  static OnboardingTourConfig fromJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return fromMap(decoded);
      }
    } catch (_) {}
    return empty();
  }

  static OnboardingTourConfig fromMap(Map<String, dynamic> map) {
    final welcomeRaw = map['welcome_message'];
    final welcome = welcomeRaw is Map<String, dynamic>
        ? WelcomeMessage.fromMap(welcomeRaw)
        : null;

    final tourRaw = map['tour'];
    final steps = <TourStep>[];
    if (tourRaw is List) {
      for (final item in tourRaw) {
        if (item is Map<String, dynamic>) {
          steps.add(TourStep.fromMap(item));
        }
      }
    }

    return OnboardingTourConfig(
      welcomeMessage: welcome,
      tour: steps,
      postTourTip: map['post_tour_tip']?.toString(),
      revisitInstructions: map['revisit_instructions']?.toString(),
    );
  }
}

class WelcomeMessage {
  final String? title;
  final String? body;

  const WelcomeMessage({required this.title, required this.body});

  static WelcomeMessage fromMap(Map<String, dynamic> map) {
    return WelcomeMessage(
      title: map['title']?.toString(),
      body: map['body']?.toString(),
    );
  }
}

class TourStep {
  final String id;
  final String? screen;
  final SpotlightConfig spotlight;
  final String? title;
  final String? body;
  final String? userAction;
  final ButtonSpec? primaryButton;
  final ButtonSpec? secondaryButton;
  final String? progress;
  final String? analyticsEvent;

  const TourStep({
    required this.id,
    required this.screen,
    required this.spotlight,
    required this.title,
    required this.body,
    required this.userAction,
    required this.primaryButton,
    required this.secondaryButton,
    required this.progress,
    required this.analyticsEvent,
  });

  static TourStep fromMap(Map<String, dynamic> map) {
    final spotlightRaw = map['spotlight'];
    final spotlight = spotlightRaw is Map<String, dynamic>
        ? SpotlightConfig.fromMap(spotlightRaw)
        : SpotlightConfig.empty();

    return TourStep(
      id: map['id']?.toString() ?? '',
      screen: map['screen']?.toString(),
      spotlight: spotlight,
      title: map['title']?.toString(),
      body: map['body']?.toString(),
      userAction: map['user_action']?.toString(),
      primaryButton: ButtonSpec.fromUnknown(map['primary_button']),
      secondaryButton: ButtonSpec.fromUnknown(map['secondary_button']),
      progress: map['progress']?.toString(),
      analyticsEvent: map['analytics_event']?.toString(),
    );
  }
}

class SpotlightConfig {
  final String targetElementName;
  final String? shape;
  final double paddingPx;
  final double shroudOpacity;
  final double radiusMultiplier;

  const SpotlightConfig({
    required this.targetElementName,
    required this.shape,
    required this.paddingPx,
    required this.shroudOpacity,
    required this.radiusMultiplier,
  });

  static SpotlightConfig empty() {
    return const SpotlightConfig(
      targetElementName: '',
      shape: null,
      paddingPx: 8,
      shroudOpacity: 0.72,
      radiusMultiplier: 1.0,
    );
  }

  static SpotlightConfig fromMap(Map<String, dynamic> map) {
    final padding = map['padding_px'];
    final opacity = map['shroud_opacity'];
    final radiusMultiplier = map['radius_multiplier'];

    return SpotlightConfig(
      targetElementName: map['target_element_name']?.toString() ?? '',
      shape: map['shape']?.toString(),
      paddingPx: padding is num ? padding.toDouble() : 8,
      shroudOpacity: opacity is num ? opacity.toDouble() : 0.72,
      radiusMultiplier: radiusMultiplier is num
          ? radiusMultiplier.toDouble()
          : 1.0,
    );
  }
}

class ButtonSpec {
  final String label;
  final String? action;

  const ButtonSpec({required this.label, required this.action});

  static ButtonSpec? fromUnknown(Object? raw) {
    if (raw == null) return null;
    if (raw is String) {
      final label = raw.trim();
      if (label.isEmpty) return null;
      return ButtonSpec(label: label, action: null);
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final label = map['label']?.toString().trim() ?? '';
      if (label.isEmpty) return null;
      return ButtonSpec(label: label, action: map['action']?.toString());
    }
    return null;
  }
}
