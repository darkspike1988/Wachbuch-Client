import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';
import 'package:wachbuch_mobile/screens/inspections_screen.dart';

import 'test_localization.dart';

class _FakeInspectionApi extends WachbuchApi {
  _FakeInspectionApi() : super(baseUrl: 'https://wache.example.org', token: 'wb_test');

  int recorded = 0;

  @override
  Future<List<StationAsset>> dueInspections() async => const [
        StationAsset(
          id: 'atem-1',
          label: 'Atemschutz 1',
          inspectionState: 'overdue',
        ),
      ];

  @override
  Future<AssetCard> assetCard(String assetId) async => const AssetCard(
        asset: StationAsset(
          id: 'atem-1',
          label: 'Atemschutz 1',
          inspectionIntervalDays: 365,
          inspectionState: 'ok',
        ),
        inspections: [
          AssetInspectionRecord(result: 'ok', note: 'geprüft', by: 'lead'),
        ],
        openDefects: [
          OpenDefectRef(id: 1, title: 'Maske undicht', priority: 'urgent'),
        ],
      );

  @override
  Future<StationAsset> recordInspection(String assetId,
      {String result = 'ok', String note = ''}) async {
    recorded++;
    return const StationAsset(id: 'atem-1', label: 'Atemschutz 1', inspectionState: 'ok');
  }
}

void main() {
  testWidgets('due list shows overdue device with state chip', (tester) async {
    await tester.pumpWidget(
      localizedApp(home: DueInspectionsScreen(api: _FakeInspectionApi())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Atemschutz 1'), findsOneWidget);
    expect(find.text('Überfällig'), findsOneWidget);
  });

  testWidgets('device card shows history, open defects and records inspection',
      (tester) async {
    final api = _FakeInspectionApi();
    await tester.pumpWidget(
      localizedApp(
        home: AssetCardScreen(api: api, assetId: 'atem-1', title: 'Atemschutz 1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maske undicht'), findsOneWidget);
    // History entry ("In Ordnung") and the record button both exist.
    expect(find.text('Offene Mängel'), findsOneWidget);

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    expect(api.recorded, 1);
  });
}
