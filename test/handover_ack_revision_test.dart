import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/handover_ack.dart';
import 'package:wachbuch_mobile/screens/home_shell.dart';

import 'test_localization.dart';

/// Minimal fake that serves a single handover and records acknowledgement calls.
/// Mirrors the real contract: ack takes a required revision, a stale revision
/// raises `409 conflict`.
class _FakeHandoverApi extends WachbuchApi {
  _FakeHandoverApi({
    required this.detail,
    List<HandoverAck> acks = const [],
    this.ackError,
  }) : acks = List<HandoverAck>.from(acks),
       super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  Map<String, dynamic> detail;
  List<HandoverAck> acks;
  final ApiException? ackError;
  int ackCalls = 0;
  int? lastAckedVersion;

  @override
  Future<Map<String, dynamic>> me() async => {
    'user': {'username': 'michael'},
    'membership': {
      'role_label': 'Schichtleitung',
      'station': {
        'name': 'Rettungswache Test',
        'modules': {
          'defects': true,
          'reports': true,
          'assets': false,
          'inventory': false,
        },
      },
    },
  };

  @override
  Future<List<Map<String, dynamic>>> handovers() async => [
    {
      'id': detail['id'],
      'title': detail['title'],
      'priority': detail['priority'],
      'status': detail['status'],
      'category': detail['category'],
    },
  ];

  @override
  Future<Map<String, dynamic>> handoverDetail(int id) async => detail;

  @override
  Future<List<HandoverAck>> handoverAcks(int id) async =>
      List<HandoverAck>.unmodifiable(acks);

  @override
  Future<HandoverAck> acknowledgeHandover(
    int id, {
    required int version,
  }) async {
    ackCalls++;
    lastAckedVersion = version;
    final error = ackError;
    if (error != null) throw error;
    final ack = HandoverAck(
      handoverId: id,
      by: 'michael',
      at: DateTime.now(),
      version: version,
    );
    acks = [...acks, ack];
    return ack;
  }

  @override
  void close() {}
}

Map<String, dynamic> _detail({Object? version = 2}) => <String, dynamic>{
  'id': 1,
  'title': 'Defi-Akku prüfen',
  'details': 'Kapazität nach Einsatz kontrollieren.',
  'priority': 'urgent',
  'status': 'open',
  'category': 'material',
  'version': ?version,
};

final _ackButton = find.byKey(const Key('handover-ack'));

Future<void> _openSheet(WidgetTester tester, _FakeHandoverApi api) async {
  tester.view.physicalSize = const Size(500, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    localizedApp(
      home: HomeShell(
        api: api,
        onLogout: () async {},
        onChangeServer: () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Übergaben'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Defi-Akku prüfen'));
  await tester.pumpAndSettle();
}

class _DelayedAcksApi extends _FakeHandoverApi {
  _DelayedAcksApi() : super(detail: _detail());
  final pending = Completer<List<HandoverAck>>();
  @override
  Future<List<HandoverAck>> handoverAcks(int id) => pending.future;
}

void main() {
  for (final invalid in <String, double>{
    'infinite': double.infinity,
    'negative infinite': double.negativeInfinity,
    'NaN': double.nan,
    'oversized finite': 1e30,
  }.entries) {
    testWidgets(
      '${invalid.key} detail revision locks acknowledgement without crashing',
      (tester) async {
        final api = _FakeHandoverApi(detail: _detail(version: invalid.value));
        await _openSheet(tester, api);
        expect(tester.takeException(), isNull);
        expect(tester.widget<FilledButton>(_ackButton).onPressed, isNull);
        expect(api.ackCalls, 0);
      },
    );
  }

  testWidgets('late ack GET cannot erase successful local acknowledgement', (
    tester,
  ) async {
    final api = _DelayedAcksApi();
    await _openSheet(tester, api);
    await tester.ensureVisible(_ackButton);
    await tester.tap(_ackButton);
    await tester.pumpAndSettle();
    expect(find.text('Von Ihnen quittiert'), findsOneWidget);
    api.pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Von Ihnen quittiert'), findsOneWidget);
    expect(api.ackCalls, 1);
  });
  testWidgets(
    'a receipt for an older revision does not mark the current one as read',
    (tester) async {
      final api = _FakeHandoverApi(
        detail: _detail(version: 2),
        acks: [
          HandoverAck(
            handoverId: 1,
            by: 'michael',
            at: DateTime.utc(2026, 8, 9, 6),
            version: 1,
          ),
        ],
      );
      await _openSheet(tester, api);

      // The old v1 receipt must not read as "by you" for the current v2.
      expect(find.text('Von Ihnen quittiert'), findsNothing);
      expect(
        tester.widget<FilledButton>(_ackButton).onPressed,
        isNotNull,
        reason: 'the current revision is still unacknowledged',
      );

      await tester.ensureVisible(_ackButton);
      await tester.tap(_ackButton);
      await tester.pumpAndSettle();

      // The exact read revision is sent, then the current receipt shows.
      expect(api.ackCalls, 1);
      expect(api.lastAckedVersion, 2);
      expect(find.text('Von Ihnen quittiert'), findsOneWidget);
    },
  );

  testWidgets(
    'a missing revision fails closed: action locked and reload requested',
    (tester) async {
      final api = _FakeHandoverApi(detail: _detail(version: null));
      await _openSheet(tester, api);

      expect(
        tester.widget<FilledButton>(_ackButton).onPressed,
        isNull,
        reason: 'no revision -> never guess, lock the acknowledgement',
      );
      expect(
        find.text(
          'Fassung der Übergabe unbekannt. Bitte neu laden, um zu quittieren.',
        ),
        findsOneWidget,
      );
      expect(api.ackCalls, 0);
    },
  );

  testWidgets(
    'a stale acknowledgement shows a reload hint and is never retried',
    (tester) async {
      final api = _FakeHandoverApi(
        detail: _detail(version: 5),
        ackError: ApiException(
          409,
          'Die Uebergabe wurde zwischenzeitlich geaendert.',
          code: 'conflict',
        ),
      );
      await _openSheet(tester, api);

      await tester.ensureVisible(_ackButton);
      await tester.tap(_ackButton);
      await tester.pumpAndSettle();

      expect(api.ackCalls, 1, reason: '409 must not be auto-replayed');
      expect(
        find.text(
          'Die Übergabe wurde zwischenzeitlich geändert. '
          'Bitte neu laden und erneut quittieren.',
        ),
        findsOneWidget,
      );
      // No receipt was recorded, so the action stays available for a reload.
      expect(find.text('Von Ihnen quittiert'), findsNothing);
      expect(tester.widget<FilledButton>(_ackButton).onPressed, isNotNull);
    },
  );

  testWidgets(
    'legacy receipts without a revision are labelled, not treated as current',
    (tester) async {
      final api = _FakeHandoverApi(
        detail: _detail(version: 3),
        acks: [
          HandoverAck(
            handoverId: 1,
            by: 'michael',
            at: DateTime.utc(2026, 8, 9, 6),
          ),
          HandoverAck(
            handoverId: 1,
            by: 'alice',
            at: DateTime.utc(2026, 8, 9, 7),
            version: 3,
          ),
        ],
      );
      await _openSheet(tester, api);

      // A legacy receipt (no revision) is shown but never counts as "by you".
      expect(find.textContaining('Fassung unbekannt'), findsOneWidget);
      expect(find.text('Von Ihnen quittiert'), findsNothing);
      expect(tester.widget<FilledButton>(_ackButton).onPressed, isNotNull);
    },
  );
}
