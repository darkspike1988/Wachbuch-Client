import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/screens/home_shell.dart';

Map<String, dynamic> _mePayload({String stationName = 'Rettungswache Test'}) {
  return {
    'user': {'username': 'michael'},
    'membership': {
      'role_label': 'Schichtleitung',
      'station': {
        'name': stationName,
        'modules': {'coffee': true, 'calendar': false},
      },
    },
  };
}

class _ImmediateApi extends WachbuchApi {
  _ImmediateApi()
    : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  bool closed = false;

  @override
  Future<Map<String, dynamic>> me() async => _mePayload();

  @override
  Future<List<Map<String, dynamic>>> handovers() async => [
    {
      'title': 'RTW auffüllen',
      'priority': 'urgent',
      'status': 'open',
      'category': 'task',
    },
  ];

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class _ControlledApi extends WachbuchApi {
  _ControlledApi(this.meResult)
    : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  final Completer<Map<String, dynamic>> meResult;

  @override
  Future<Map<String, dynamic>> me() => meResult.future;

  @override
  Future<List<Map<String, dynamic>>> handovers() async => [];
}

class _ReloadApi extends WachbuchApi {
  _ReloadApi({this.stationName = 'Rettungswache Test'})
    : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  final String stationName;
  final secondMe = Completer<Map<String, dynamic>>();
  int calls = 0;

  @override
  Future<Map<String, dynamic>> me() {
    calls += 1;
    if (calls == 1) {
      return Future.value(_mePayload(stationName: stationName));
    }
    return secondMe.future;
  }

  @override
  Future<List<Map<String, dynamic>>> handovers() async => [];
}

void main() {
  testWidgets('renders station, handovers and account data', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          api: _ImmediateApi(),
          onLogout: () async {},
          onChangeServer: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rettungswache Test'), findsWidgets);
    expect(find.text('1'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.tap(find.text('Übergaben'));
    await tester.pumpAndSettle();
    expect(find.text('RTW auffüllen'), findsOneWidget);

    await tester.tap(find.text('Konto'));
    await tester.pumpAndSettle();
    expect(find.text('michael'), findsOneWidget);
    expect(find.text('https://wache.example.org'), findsOneWidget);
  });

  testWidgets('tablet layout uses Material NavigationRail', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          api: _ImmediateApi(),
          onLogout: () async {},
          onChangeServer: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('late API errors do not call setState after dispose', (
    tester,
  ) async {
    final response = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          api: _ControlledApi(response),
          onLogout: () async {},
          onChangeServer: () async {},
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    response.completeError(ApiException(503, 'Server nicht erreichbar.'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing HomeShell closes its API client', (tester) async {
    final api = _ImmediateApi();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          api: api,
          onLogout: () async {},
          onChangeServer: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    expect(api.closed, isTrue);
  });

  testWidgets('account actions are disabled during reload', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _ReloadApi();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          api: api,
          onLogout: () async {},
          onChangeServer: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konto'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Profil aktualisieren'),
    );
    await tester.pump();

    final refresh = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Profil aktualisieren'),
    );
    final logout = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Abmelden'),
    );
    final changeServer = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Anderen Server einrichten'),
    );
    expect(refresh.onPressed, isNull);
    expect(logout.onPressed, isNull);
    expect(changeServer.onPressed, isNull);

    api.secondMe.complete(_mePayload());
    await tester.pumpAndSettle();
  });

  testWidgets('station named Wachbuch keeps content visible during reload', (
    tester,
  ) async {
    final api = _ReloadApi(stationName: 'Wachbuch');
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          api: api,
          onLogout: () async {},
          onChangeServer: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aktive Übergaben'), findsOneWidget);

    await tester.tap(find.byTooltip('Aktualisieren'));
    await tester.pump();

    expect(find.text('Aktive Übergaben'), findsOneWidget);

    api.secondMe.complete(_mePayload(stationName: 'Wachbuch'));
    await tester.pumpAndSettle();
  });
}
