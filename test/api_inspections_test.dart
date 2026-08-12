import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/client.dart';

void main() {
  const baseUrl = 'https://wache.example.org';
  WachbuchApi api(MockClient c) => WachbuchApi(baseUrl: baseUrl, token: 'wb_test', client: c);

  group('WachbuchApi inspections', () {
    test('GET asset card parses history and open defects', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/assets/atem-1/');
        return http.Response(
          jsonEncode({
            'id': 'atem-1',
            'label': 'Atemschutz 1',
            'kind': 'device',
            'status': 'ready',
            'inspection_interval_days': 365,
            'last_inspected_at': '2026-01-01',
            'next_inspection_date': '2027-01-01',
            'inspection_state': 'ok',
            'inspections': [
              {'result': 'ok', 'note': 'geprüft', 'by': 'lead', 'at': '2026-01-01T09:00:00Z'},
            ],
            'open_defects': [
              {'id': 4, 'title': 'Maske undicht', 'priority': 'urgent'},
            ],
          }),
          200,
        );
      });
      final card = await api(client).assetCard('atem-1');
      expect(card.asset.inspectionState, 'ok');
      expect(card.asset.inspectionIntervalDays, 365);
      expect(card.inspections.single.by, 'lead');
      expect(card.openDefects.single.title, 'Maske undicht');
    });

    test('POST record inspection sends result and note', () async {
      Map<String, dynamic>? sent;
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/assets/atem-1/inspection/');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'id': 'atem-1', 'label': 'A', 'inspection_state': 'ok'}),
          201,
        );
      });
      final asset = await api(client).recordInspection('atem-1', result: 'defect', note: 'Riss');
      expect(asset.inspectionState, 'ok');
      expect(sent!['result'], 'defect');
      expect(sent!['note'], 'Riss');
    });

    test('PUT schedule sends interval days', () async {
      Map<String, dynamic>? sent;
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/assets/atem-1/inspection-schedule/');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'id': 'atem-1', 'label': 'A', 'inspection_interval_days': 90,
                      'inspection_state': 'unknown'}),
          200,
        );
      });
      final asset = await api(client).setInspectionSchedule('atem-1', 90);
      expect(asset.inspectionIntervalDays, 90);
      expect(sent!['interval_days'], 90);
    });

    test('GET due inspections parses list', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/inspections/due/');
        return http.Response(
          jsonEncode({
            'results': [
              {'id': 'a', 'label': 'A', 'inspection_state': 'overdue'},
              {'id': 'b', 'label': 'B', 'inspection_state': 'due_soon'},
            ],
          }),
          200,
        );
      });
      final due = await api(client).dueInspections();
      expect(due.length, 2);
      expect(due.first.inspectionState, 'overdue');
      expect(due.first.inspectionNeedsAttention, isTrue);
    });
  });
}
