import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/state/handover_ack_state.dart';

class _RealHttp extends HttpOverrides {}

void main() {
  test('real Django HTTP revision acknowledgement and history', () async {
    final origin = Platform.environment['WACHBUCH_QA_ORIGIN'];
    final token = Platform.environment['WACHBUCH_QA_TOKEN'];
    final id = int.parse(Platform.environment['WACHBUCH_QA_ID']!);
    expect(origin, startsWith('http://127.0.0.1:'));
    expect(token, isNotNull);
    await HttpOverrides.runZoned(() async {
      final api = WachbuchApi(baseUrl: origin!, token: token);
      final raw = http.Client();
      final receipts = HandoverAckState(api: api, handoverId: id);
      try {
        final first = await api.handoverDetail(id);
        expect(first['version'], 1);
        expect((await api.acknowledgeHandover(id, version: 1)).version, 1);
        expect((await api.acknowledgeHandover(id, version: 1)).version, 1);
        await receipts.load();
        expect(receipts.loadFailed, isFalse);
        expect(receipts.receipts.single.version, 1);
        final advance = await raw.post(
          Uri.parse('$origin/_qa/advance'),
          headers: {'Authorization': 'Token $token'},
        );
        expect(advance.statusCode, 200);
        await receipts.acknowledge(1);
        expect(receipts.failure, HandoverAckFailure.stale);
        expect(receipts.receipts.single.version, 1);
        try {
          await api.acknowledgeHandover(id, version: 1);
          fail('stale acknowledgement must fail');
        } on ApiException catch (error) {
          expect(error.statusCode, 409);
        }
        final second = await api.handoverDetail(id);
        expect(second['version'], 2);
        await receipts.acknowledge(2);
        expect(receipts.failure, isNull);
        expect(receipts.receipts.map((ack) => ack.version), [1, 2]);
        expect((await api.acknowledgeHandover(id, version: 2)).version, 2);
        final history = await api.handoverAcks(id);
        expect(
          history.map((ack) => ack.version).toList()
            ..sort((a, b) => a!.compareTo(b!)),
          [1, 2],
        );
        final missing = await raw.post(
          Uri.parse('$origin/api/v1/handovers/$id/ack/'),
          headers: {
            'Authorization': 'Token $token',
            'Content-Type': 'application/json',
          },
          body: '{}',
        );
        expect(missing.statusCode, 422);
      } finally {
        receipts.dispose();
        api.close();
        raw.close();
      }
    }, createHttpClient: (context) => _RealHttp().createHttpClient(context));
  });
}
