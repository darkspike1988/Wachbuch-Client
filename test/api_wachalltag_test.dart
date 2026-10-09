import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wachbuch_mobile/api/client.dart';

void main() {
  const baseUrl = 'https://wache.example.org';

  group('WachbuchApi defects/assets/inventory/acks', () {
    test('GET defects parses results with auth header', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/defects/');
        expect(request.headers['Authorization'], 'Token wb_test');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'id': 1,
                'title': 'Defi',
                'status': 'open',
                'priority': 'urgent',
              },
            ],
          }),
          200,
        );
      });

      final items = await WachbuchApi(
        baseUrl: baseUrl,
        token: 'wb_test',
        client: client,
      ).defects();

      expect(items.single.title, 'Defi');
      expect(items.single.isUrgent, isTrue);
    });

    test('POST defect status sends body', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/defects/9/status/');
        expect(jsonDecode(request.body), {'status': 'waiting'});
        return http.Response(
          jsonEncode({'id': 9, 'title': 'X', 'status': 'waiting'}),
          200,
        );
      });

      final updated = await WachbuchApi(
        baseUrl: baseUrl,
        token: 't',
        client: client,
      ).updateDefectStatus(9, 'waiting');

      expect(updated.status, 'waiting');
    });

    test('missing defects module (404) is non-retryable', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(jsonEncode({'error': 'missing'}), 404);
      });

      await expectLater(
        WachbuchApi(baseUrl: baseUrl, token: 't', client: client).defects(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
      expect(calls, 1);
      expect(WachbuchApi.isModuleUnavailable(ApiException(404, 'x')), isTrue);
    });

    test('HTTP 501 from server is not retried', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(jsonEncode({'error': 'not implemented'}), 501);
      });

      await expectLater(
        WachbuchApi(baseUrl: baseUrl, token: 't', client: client).assets(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', 501),
        ),
      );
      expect(calls, 1);
    });

    test('GET assets and inventory', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/assets/') {
          return http.Response(
            jsonEncode({
              'results': [
                {'id': 'rtw-1', 'label': 'RTW 1', 'status': 'ready'},
              ],
            }),
            200,
          );
        }
        expect(request.url.path, '/api/v1/inventory/');
        return http.Response(
          jsonEncode({
            'results': [
              {'id': 'funk-a', 'label': 'Funk A', 'kind': 'device'},
            ],
          }),
          200,
        );
      });

      final api = WachbuchApi(baseUrl: baseUrl, token: 't', client: client);
      expect((await api.assets()).single.label, 'RTW 1');
      expect((await api.inventory()).single.id, 'funk-a');
    });

    test('inventory checkout and checkin paths', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        if (request.url.path.endsWith('/checkout/')) {
          return http.Response(
            jsonEncode({
              'id': 'funk-a',
              'label': 'Funk A',
              'holder': 'michael',
            }),
            200,
          );
        }
        expect(request.url.path, '/api/v1/inventory/funk-a/checkin/');
        return http.Response(
          jsonEncode({'id': 'funk-a', 'label': 'Funk A', 'holder': null}),
          200,
        );
      });

      final api = WachbuchApi(baseUrl: baseUrl, token: 't', client: client);
      final out = await api.inventoryCheckout('funk-a');
      expect(out.isOut, isTrue);
      final back = await api.inventoryCheckin('funk-a');
      expect(back.isOut, isFalse);
    });

    test('handover ack list and revision-bound post', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          expect(request.url.path, '/api/v1/handovers/3/acks/');
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'handover_id': 3,
                  'by': 'alice',
                  'at': '2026-08-09T06:00:00Z',
                },
              ],
            }),
            200,
          );
        }
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/handovers/3/ack/');
        // The acknowledgement must carry the exact revision that was read.
        expect(jsonDecode(request.body), {'version': 7});
        return http.Response(
          jsonEncode({
            'handover_id': 3,
            'by': 'michael',
            'at': '2026-08-09T07:00:00Z',
            'version': 7,
          }),
          201,
        );
      });

      final api = WachbuchApi(baseUrl: baseUrl, token: 't', client: client);
      final acks = await api.handoverAcks(3);
      expect(acks.single.by, 'alice');
      expect(acks.single.version, isNull); // legacy ack, revision unknown
      final posted = await api.acknowledgeHandover(3, version: 7);
      expect(posted.by, 'michael');
      expect(posted.version, 7);
    });

    test('stale acknowledgement surfaces 409 conflict unchanged', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(jsonDecode(request.body), {'version': 1});
        return http.Response(
          jsonEncode({
            'ok': false,
            'error': {
              'code': 'conflict',
              'message': 'Die Uebergabe wurde zwischenzeitlich geaendert.',
              'correlation_id': 'corr-409',
            },
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = WachbuchApi(baseUrl: baseUrl, token: 't', client: client);
      await expectLater(
        api.acknowledgeHandover(3, version: 1),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.code, 'code', 'conflict')
              .having((e) => e.correlationId, 'correlationId', 'corr-409'),
        ),
      );
      // A stale acknowledgement must never be replayed automatically.
      expect(calls, 1);
    });

    test('non-positive acknowledgement version fails closed locally', () async {
      var calls = 0;
      final api = WachbuchApi(
        baseUrl: baseUrl,
        token: 't',
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        api.acknowledgeHandover(3, version: 0),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 422),
        ),
      );
      expect(calls, 0);
    });
  });

  group('WachbuchApi defect detail and PATCH (contract 1.3.1)', () {
    test('GET defect detail parses events and attachment metadata', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/defects/7/');
        expect(request.headers['Authorization'], 'Token wb_test');
        return http.Response(
          jsonEncode({
            'ok': true,
            'id': 7,
            'title': 'Tür defekt',
            'status': 'in_progress',
            'priority': 'important',
            'category': 'facility',
            'attachment_count': 1,
            'events': [
              {
                'kind': 'status',
                'from_status': 'open',
                'to_status': 'in_progress',
                'by': 'alice',
                'at': '2026-08-09T06:00:00Z',
              },
              {
                'kind': 'created',
                'from_status': null,
                'to_status': 'open',
                'by': 'bob',
                'at': '2026-08-08T06:00:00Z',
              },
            ],
            'attachments': [
              {
                'id': 3,
                'defect_id': 7,
                'filename': 'tuer.jpg',
                'content_type': 'image/jpeg',
                'size': 2048,
                'uploaded_by': 'alice',
                'download_url': '/api/v1/attachments/3/',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final detail = await WachbuchApi(
        baseUrl: baseUrl,
        token: 'wb_test',
        client: client,
      ).defectDetail(7);

      expect(detail.defect.id, 7);
      expect(detail.defect.status, 'in_progress');
      expect(detail.events.length, 2);
      expect(detail.events.first.kind, 'status');
      expect(detail.events.first.toStatus, 'in_progress');
      expect(detail.events.last.fromStatus, isNull);
      expect(detail.attachments.single.filename, 'tuer.jpg');
    });

    test('PATCH defect sends only changeable fields (no title/category)', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/defects/7/');
        expect(request.headers['Authorization'], 'Token wb_test');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'ok': true,
            'id': 7,
            'title': 'Tür defekt',
            'status': 'open',
            'priority': 'urgent',
            'owner': 'alice',
            'category': 'facility',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final updated = await WachbuchApi(
        baseUrl: baseUrl,
        token: 'wb_test',
        client: client,
      ).updateDefect(7, priority: 'urgent', owner: 'alice', description: 'neu');

      expect(sent.keys.toSet(), {'priority', 'owner', 'description'});
      expect(sent.containsKey('title'), isFalse);
      expect(sent.containsKey('category'), isFalse);
      expect(updated.priority, 'urgent');
    });

    test('PATCH defect clears the due date with an explicit null', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'ok': true, 'id': 7, 'title': 'x'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await WachbuchApi(
        baseUrl: baseUrl,
        token: 't',
        client: client,
      ).updateDefect(7, clearDueAt: true);

      expect(sent.containsKey('due_at'), isTrue);
      expect(sent['due_at'], isNull);
    });

    test('PATCH defect rejects an empty body locally with 422', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });

      await expectLater(
        WachbuchApi(baseUrl: baseUrl, token: 't', client: client).updateDefect(7),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 422),
        ),
      );
      expect(calls, 0);
    });

    test('PATCH defect surfaces a canonical server error unchanged', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'ok': false,
              'error': {
                'code': 'validation_error',
                'message': 'Keine aenderbaren Felder angegeben.',
                'correlation_id': 'corr-9',
              },
            }),
            422,
            headers: {'content-type': 'application/json'},
          ));

      await expectLater(
        WachbuchApi(baseUrl: baseUrl, token: 't', client: client)
            .updateDefect(7, priority: 'urgent'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.code, 'code', 'validation_error')
              .having((e) => e.correlationId, 'correlationId', 'corr-9'),
        ),
      );
    });
  });
}
