import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/chat.dart';
import 'package:wachbuch_mobile/screens/secure_mail_screen.dart';
import 'package:wachbuch_mobile/state/crypto_session.dart';

import 'test_localization.dart';

class _FakeMailApi extends WachbuchApi {
  _FakeMailApi() : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  @override
  Future<MailInboxData> mailInbox() async => const MailInboxData(
        received: [MailSummary(id: 7, senderId: 2, senderName: 'Alex')],
        sent: [],
        colleagues: [],
      );

  @override
  Future<MailDetailData> mailDetail(int id) async => MailDetailData(
        envelope: ChatFeedItem(
          id: id,
          authorId: 2,
          authorName: 'Alex',
          isOwn: false,
          isEncrypted: false,
          legacyBody: jsonEncode({'subject': 'Wartung', 'body': 'RTW 1 morgen zur Inspektion.'}),
        ),
        recipients: const [MailRecipientStatus(id: 1, name: 'Ich', read: true)],
      );
}

void main() {
  testWidgets('inbox lists received mail', (tester) async {
    await tester.pumpWidget(
      localizedApp(home: SecureMailScreen(api: _FakeMailApi(), session: CryptoSession())),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Alex'), findsOneWidget);
  });

  testWidgets('detail decrypts subject and body from the JSON envelope', (tester) async {
    final session = CryptoSession()..unlockWith(<String, dynamic>{'kty': 'EC'});
    await tester.pumpWidget(
      localizedApp(
        home: MailDetailScreen(api: _FakeMailApi(), mailId: 7, title: 'Alex', session: session),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wartung'), findsOneWidget);
    expect(find.text('RTW 1 morgen zur Inspektion.'), findsOneWidget);
  });
}
