import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/theme/app_theme.dart';

/// WCAG contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final light = la > lb ? la : lb;
  final dark = la > lb ? lb : la;
  return (light + 0.05) / (dark + 0.05);
}

Color _labelColor(WidgetTester tester, String text) {
  final element = tester.element(find.text(text));
  final style = DefaultTextStyle.of(
    element,
  ).style.merge((element.widget as Text).style);
  final color = style.color;
  expect(color, isNotNull, reason: '"$text" has no text color at all');
  // WidgetStateColor resolves to the enabled/unselected value when read
  // directly; the chip resolves it per state before painting.
  return color is WidgetStateColor ? color.resolve(const {}) : color!;
}

void main() {
  testWidgets('chip labels are legible on their chips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Column(
            children: [
              ActionChip(label: const Text('action'), onPressed: () {}),
              ChoiceChip(
                label: const Text('choice'),
                selected: false,
                onSelected: (_) {},
              ),
              ChoiceChip(
                label: const Text('chosen'),
                selected: true,
                onSelected: (_) {},
              ),
              FilterChip(
                label: const Text('filter'),
                selected: false,
                onSelected: (_) {},
              ),
              const Chip(label: Text('plain')),
            ],
          ),
        ),
      ),
    );
    final chipTheme = AppTheme.lightTheme.chipTheme;
    for (final text in ['action', 'choice', 'filter', 'plain']) {
      final ratio = _contrast(
        _labelColor(tester, text),
        chipTheme.backgroundColor!,
      );
      expect(
        ratio,
        greaterThan(4.5),
        reason: '"$text" on a plain chip: $ratio',
      );
    }
    final selected = AppTheme.lightTheme.chipTheme.labelStyle!.color!;
    final selectedColor = (selected as WidgetStateColor).resolve({
      WidgetState.selected,
    });
    expect(
      _contrast(selectedColor, chipTheme.selectedColor!),
      greaterThan(4.5),
      reason: 'selected chip label on its light-cyan fill',
    );
  });

  test('brand text colors clear WCAG AA on the canvas and on white', () {
    for (final background in [AppColors.canvas, Colors.white]) {
      expect(_contrast(AppColors.textBlack, background), greaterThan(4.5));
      expect(_contrast(AppColors.primary, background), greaterThan(4.5));
      expect(_contrast(AppColors.primaryDark, background), greaterThan(4.5));
    }
    expect(_contrast(AppColors.textWhite, AppColors.primary), greaterThan(4.5));
    expect(
      _contrast(AppColors.textWhite, AppColors.primaryDark),
      greaterThan(7),
    );
  });
}
