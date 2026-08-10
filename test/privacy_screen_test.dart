import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/screens/privacy_screen.dart';

import 'test_localization.dart';

void main() {
  testWidgets('privacy policy renders German store copy', (tester) async {
    await tester.pumpWidget(localizedApp(home: const PrivacyScreen()));
    await tester.binding.setLocale('de', '');
    await tester.pumpAndSettle();

    expect(find.text('Datenschutz'), findsOneWidget);
    expect(find.textContaining('keine zentrale Wachbuch-Cloud'), findsOneWidget);
    expect(find.textContaining('docs/PRIVACY-POLICY.md'), findsOneWidget);
  });

  testWidgets('privacy policy renders English store copy', (tester) async {
    await tester.pumpWidget(localizedApp(home: const PrivacyScreen()));
    await tester.binding.setLocale('en', '');
    await tester.pumpAndSettle();

    expect(find.text('Privacy'), findsOneWidget);
    expect(find.textContaining('open-source client'), findsOneWidget);
    expect(find.textContaining('no advertising'), findsOneWidget);
  });
}
