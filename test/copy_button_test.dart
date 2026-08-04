import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/ui/copy_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('copy button writes value to clipboard and shows snackbar', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CopyIconButton(
            value: 'DE89370400440532013000',
            snackbarText: 'IBAN kopiert',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('copy-button')));
    await tester.pump();

    expect(copied, 'DE89370400440532013000');
    expect(find.text('IBAN kopiert'), findsOneWidget);
  });
}
