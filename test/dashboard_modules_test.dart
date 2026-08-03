import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/models/kaffeekasse.dart';
import 'package:wachbuch_mobile/models/kalender_entry.dart';
import 'package:wachbuch_mobile/screens/home_shell.dart';

class _ModulesApi extends WachbuchApi {
  _ModulesApi() : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  @override
  Future<Map<String, dynamic>> me() async => {
        'user': {'username': 'michael'},
        'membership': {
          'role_label': 'Schichtleitung',
          'station': {
            'name': 'Rettungswache Test',
            'modules': {
              'calendar': true,
              'coffee': true,
              'checklists': true,
            },
          },
        },
      };

  @override
  Future<List<Map<String, dynamic>>> handovers() async => [];

  @override
  Future<List<KalenderEntry>> kalender() async => [
        KalenderEntry(id: 1, title: 'RTW-Dienst'),
      ];

  @override
  Future<Kaffeekasse> kaffeekasse() async =>
      Kaffeekasse(balance: '10,00 €', currency: 'EUR');

  @override
  Future<List<Checklist>> checklisten() async => [
        Checklist(id: 1, title: 'Tagescheckliste'),
      ];
}

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('module tiles navigate to their screens', (tester) async {
    _usePhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          api: _ModulesApi(),
          onLogout: () async {},
          onChangeServer: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('module-tile-calendar')), findsOneWidget);
    expect(find.byKey(const Key('module-tile-coffee')), findsOneWidget);
    expect(find.byKey(const Key('module-tile-checklists')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('module-tile-calendar')));
    await tester.tap(find.byKey(const Key('module-tile-calendar')));
    await tester.pumpAndSettle();

    expect(find.text('Kalender'), findsWidgets);
    expect(find.text('RTW-Dienst'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('module-tile-coffee')));
    await tester.tap(find.byKey(const Key('module-tile-coffee')));
    await tester.pumpAndSettle();

    expect(find.text('Kaffeekasse'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('module-tile-checklists')));
    await tester.tap(find.byKey(const Key('module-tile-checklists')));
    await tester.pumpAndSettle();

    expect(find.text('Tagescheckliste'), findsOneWidget);
  });
}
