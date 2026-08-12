import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/chat.dart';
import 'package:wachbuch_mobile/screens/private_chat_screen.dart';
import 'package:wachbuch_mobile/state/crypto_session.dart';

import 'test_localization.dart';

const Map<String, dynamic> _publicJwk = {
  'kty': 'EC',
  'crv': 'P-256',
  'x': 'AZQtv9vAQ-cNiNrOIXNMnoltPWutBNOBKBaT-vVGU1M',
  'y': 'X-eE4z_DhcDRcTARZ7-_DM0KtrG4dnc3M9lFEJAJFa0',
};

class _FakePrivateApi extends WachbuchApi {
  _FakePrivateApi() : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  int sendCount = 0;

  @override
  Future<PrivateHome> privateConversations() async => const PrivateHome(
        conversations: [ChatConversation(id: 3, otherId: 2, otherName: 'Mara')],
        colleagues: [
          ChatMemberKey(userId: 2, label: 'Mara', hasKeys: true, publicJwk: _publicJwk),
        ],
      );

  @override
  Future<PrivateThreadData> privateThread(int id) async => PrivateThreadData(
        otherId: 2,
        otherName: 'Mara',
        peerKeys: const [
          ChatMemberKey(userId: 1, label: 'Ich', hasKeys: true, publicJwk: _publicJwk),
        ],
        messages: const [
          ChatFeedItem(
            id: 1,
            authorId: 2,
            authorName: 'Mara',
            isOwn: false,
            isEncrypted: false,
            legacyBody: 'Hallo direkt',
          ),
        ],
      );

  @override
  Future<void> sendPrivateMessage(int id, Map<String, dynamic> payload) async {
    sendCount++;
  }
}

void main() {
  testWidgets('lists private conversations', (tester) async {
    await tester.pumpWidget(
      localizedApp(home: PrivateChatScreen(api: _FakePrivateApi(), session: CryptoSession())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mara'), findsOneWidget);
  });

  testWidgets('thread shows message and sends when unlocked', (tester) async {
    final api = _FakePrivateApi();
    final session = CryptoSession()..unlockWith(<String, dynamic>{'kty': 'EC'});
    await tester.pumpWidget(
      localizedApp(
        home: PrivateThreadScreen(
          api: api,
          conversationId: 3,
          title: 'Mara',
          session: session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hallo direkt'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Antwort');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(api.sendCount, 1);
  });
}
