import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/theme/app_theme.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05));
}

void main() {
  for (final brightness in Brightness.values) {
    test('explicit focused borders have contrast for $brightness', () {
      final theme = buildWachbuchTheme(brightness);
      final filled = theme.filledButtonTheme.style!.side!;
      final outlined = theme.outlinedButtonTheme.style!.side!;
      final text = theme.textButtonTheme.style!.side!;
      final focused = {WidgetState.focused};
      expect(filled.resolve(focused)!.width, 2);
      expect(
        contrast(filled.resolve(focused)!.color, theme.colorScheme.primary),
        greaterThanOrEqualTo(3),
      );
      expect(filled.resolve({})!.color, Colors.transparent);
      expect(
        filled.resolve({WidgetState.disabled, WidgetState.focused})!.color,
        Colors.transparent,
      );
      expect(outlined.resolve(focused)!.width, 3);
      expect(outlined.resolve({})!.width, 1);
      expect(
        contrast(text.resolve(focused)!.color, theme.colorScheme.surface),
        greaterThanOrEqualTo(3),
      );
      expect(text.resolve({})!.color, Colors.transparent);
    });

    testWidgets(
      'real button focus paints a border without reflow for $brightness',
      (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        final theme = buildWachbuchTheme(brightness);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: FilledButton(
                    focusNode: focus,
                    onPressed: () {},
                    child: const Text('Zur Kenntnis genommen'),
                  ),
                ),
              ),
            ),
          ),
        );
        final sizeBefore = tester.getSize(find.byType(FilledButton));
        focus.requestFocus();
        await tester.pumpAndSettle();
        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.byType(Material),
          ),
        );
        final side = (material.shape! as OutlinedBorder).side;
        expect(focus.hasFocus, isTrue);
        expect(side.width, 2);
        expect(side.strokeAlign, BorderSide.strokeAlignInside);
        expect(side.color, theme.colorScheme.onPrimary);
        expect(tester.getSize(find.byType(FilledButton)), sizeBefore);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
