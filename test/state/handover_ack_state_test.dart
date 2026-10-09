import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/handover_ack.dart';
import 'package:wachbuch_mobile/state/handover_ack_state.dart';

HandoverAck receipt({int id = 1, int? version = 2}) => HandoverAck(
  handoverId: id,
  by: 'michael',
  at: DateTime.utc(2026, 10, 9),
  version: version,
);

class FakeApi extends WachbuchApi {
  FakeApi() : super(baseUrl: 'https://test.invalid', token: 'test');
  Future<List<HandoverAck>> Function() getReceipts = () async => [];
  Future<HandoverAck> Function(int) post = (v) async => receipt(version: v);
  int posts = 0;
  @override
  Future<List<HandoverAck>> handoverAcks(int id) => getReceipts();
  @override
  Future<HandoverAck> acknowledgeHandover(int id, {required int version}) {
    posts++;
    return post(version);
  }
}

void main() {
  late FakeApi api;
  late HandoverAckState state;
  setUp(() {
    api = FakeApi();
    state = HandoverAckState(api: api, handoverId: 1);
  });
  tearDown(() {
    state.dispose();
    api.close();
  });

  test('old GET cannot erase a successful POST', () async {
    final pending = Completer<List<HandoverAck>>();
    api.getReceipts = () => pending.future;
    final load = state.load();
    expect(state.loading, isTrue);
    await state.acknowledge(2);
    pending.complete([receipt(version: 1)]);
    await load;
    expect(state.receipts.map((a) => a.version), [1, 2]);
    expect(state.acknowledgedBy('michael', 2), isTrue);
  });
  test('obsolete GET completion cannot replace latest load state', () async {
    final old = Completer<List<HandoverAck>>();
    api.getReceipts = () => old.future;
    final oldLoad = state.load();
    api.getReceipts = () async => [receipt()];
    await state.load();
    old.completeError(Exception('old failure'));
    await oldLoad;
    expect(state.loadFailed, isFalse);
    expect(state.receipts, [receipt()]);
  });
  test('network error remains retryable, not unsupported', () async {
    api.getReceipts = () => Future.error(Exception('offline'));
    await state.load();
    expect(state.supported, isTrue);
    expect(state.loadFailed, isTrue);
    api.getReceipts = () async => [receipt()];
    await state.load();
    expect(state.loadFailed, isFalse);
    expect(state.receipts, [receipt()]);
  });
  test('missing module is explicitly unavailable', () async {
    api.getReceipts = () => Future.error(ApiException(404, 'missing'));
    await state.load();
    expect(state.supported, isFalse);
    await state.acknowledge(2);
    expect(api.posts, 0);
  });
  test('duplicate simultaneous submit makes one POST', () async {
    final pending = Completer<HandoverAck>();
    api.post = (v) => pending.future;
    final first = state.acknowledge(2);
    await state.acknowledge(2);
    expect(api.posts, 1);
    pending.complete(receipt());
    await first;
    expect(state.acknowledging, isFalse);
  });
  test('stale revision is not silently retried', () async {
    api.post = (v) => Future.error(ApiException(409, 'stale'));
    await state.acknowledge(2);
    expect(state.failure, HandoverAckFailure.stale);
    expect(state.receipts, isEmpty);
    expect(api.posts, 1);
  });
  test('invalid revision never reaches network', () async {
    await state.acknowledge(0);
    expect(state.failure, HandoverAckFailure.invalidRevision);
    expect(api.posts, 0);
  });
  test('legacy and older receipts do not count as current', () async {
    api.getReceipts = () async => [receipt(version: null), receipt(version: 1)];
    await state.load();
    expect(state.acknowledgedBy('michael', 2), isFalse);
    expect(state.acknowledgedBy('other', 1), isFalse);
    expect(state.acknowledgedBy('michael', null), isFalse);
    expect(() => state.receipts.clear(), throwsUnsupportedError);
  });
  test('receipt for another handover is rejected', () async {
    api.getReceipts = () async => [receipt(id: 9)];
    await state.load();
    expect(state.loadFailed, isTrue);
    expect(state.receipts, isEmpty);
  });
  test('POST receipt with wrong revision is not a confirmation', () async {
    api.post = (v) async => receipt(version: 3);
    await state.acknowledge(2);
    expect(state.failure, HandoverAckFailure.unexpected);
    expect(state.receipts, isEmpty);
  });
  test('POST receipt for another object is not a confirmation', () async {
    api.post = (v) async => receipt(id: 9);
    await state.acknowledge(2);
    expect(state.failure, HandoverAckFailure.unexpected);
    expect(state.receipts, isEmpty);
  });
  test('successful retry clears write failure', () async {
    api.post = (v) => Future.error(Exception('offline'));
    await state.acknowledge(2);
    expect(state.failure, HandoverAckFailure.unexpected);
    api.post = (v) async => receipt(version: v);
    await state.acknowledge(2);
    expect(state.failure, isNull);
    expect(state.acknowledgedBy('michael', 2), isTrue);
  });
  test('disposed state ignores a pending response and new requests', () async {
    final local = HandoverAckState(api: api, handoverId: 1);
    final pending = Completer<List<HandoverAck>>();
    api.getReceipts = () => pending.future;
    final load = local.load();
    var changes = 0;
    local.addListener(() => changes++);
    local.dispose();
    pending.complete([receipt()]);
    await load;
    await local.acknowledge(2);
    expect(changes, 0);
    expect(api.posts, 0);
    expect(local.receipts, isEmpty);
  });
}
