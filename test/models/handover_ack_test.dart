import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/models/handover_ack.dart';

void main() {
  group('HandoverAck', () {
    test(
      'shared parser preserves exact valid revisions and rejects unsafe doubles',
      () {
        final maxExactDoubleInteger = (1 << 53) - 1;
        expect(parseHandoverRevision(3), 3);
        expect(parseHandoverRevision('4'), 4);
        expect(parseHandoverRevision(5.0), 5);
        expect(
          parseHandoverRevision(maxExactDoubleInteger.toDouble()),
          maxExactDoubleInteger,
        );
        expect(parseHandoverRevision((1 << 53).toDouble()), isNull);
        for (final value in [
          null,
          true,
          false,
          0.0,
          -1.0,
          2.5,
          '2.5',
          [],
          {},
        ]) {
          expect(parseHandoverRevision(value), isNull);
        }
      },
    );

    test(
      'non-finite and oversized double revisions fail closed without throwing',
      () {
        for (final value in [
          double.infinity,
          double.negativeInfinity,
          double.nan,
          1e30,
        ]) {
          expect(
            HandoverAck.fromJson({
              'handover_id': 1,
              'by': 'a',
              'version': value,
            }).version,
            isNull,
            reason: '$value must never become an invented revision',
          );
        }
      },
    );

    test('overflowing but syntactically valid JSON number fails closed', () {
      final decoded =
          jsonDecode('{"handover_id":1,"by":"a","version":1e309}')
              as Map<String, dynamic>;
      expect(HandoverAck.fromJson(decoded).version, isNull);
    });

    test('parses snake_case and camelCase fields', () {
      final ack = HandoverAck.fromJson({
        'handover_id': 11,
        'by': 'demo-mitglied',
        'at': '2026-08-09T06:00:00Z',
      });

      expect(ack.handoverId, 11);
      expect(ack.by, 'demo-mitglied');
      expect(ack.at.year, 2026);

      final camel = HandoverAck.fromJson({
        'handoverId': '12',
        'user': 'alice',
        'created_at': '2026-08-09T07:00:00+00:00',
      });
      expect(camel.handoverId, 12);
      expect(camel.by, 'alice');
    });

    test('toJson uses contract keys', () {
      final ack = HandoverAck(
        handoverId: 1,
        by: 'bob',
        at: DateTime.utc(2026, 8, 9, 6),
      );
      final json = ack.toJson();

      expect(json['handover_id'], 1);
      expect(json['by'], 'bob');
      expect(json['at'], isA<String>());
    });

    test('falls back when timestamp missing', () {
      final before = DateTime.now();
      final ack = HandoverAck.fromJson({'handover_id': 1, 'by': 'x'});
      expect(
        ack.at.isAfter(before.subtract(const Duration(seconds: 2))),
        isTrue,
      );
    });

    test('parses positive revision and fails closed on invalid values', () {
      expect(
        HandoverAck.fromJson({
          'handover_id': 1,
          'by': 'a',
          'version': 3,
        }).version,
        3,
      );
      expect(
        HandoverAck.fromJson({
          'handover_id': 1,
          'by': 'a',
          'version': '4',
        }).version,
        4,
      );
      // legacy / unknown revision
      expect(
        HandoverAck.fromJson({'handover_id': 1, 'by': 'a'}).version,
        isNull,
      );
      expect(
        HandoverAck.fromJson({
          'handover_id': 1,
          'by': 'a',
          'version': null,
        }).version,
        isNull,
      );
      // invalid values must never be guessed as the current revision
      for (final invalid in <Object>[0, -2, true, 'abc', 2.5]) {
        expect(
          HandoverAck.fromJson({
            'handover_id': 1,
            'by': 'a',
            'version': invalid,
          }).version,
          isNull,
          reason: 'version $invalid must fail closed',
        );
      }
    });

    test('toJson emits version only when known', () {
      final withVersion = HandoverAck(
        handoverId: 1,
        by: 'bob',
        at: DateTime.utc(2026, 8, 9, 6),
        version: 2,
      ).toJson();
      expect(withVersion['version'], 2);

      final legacy = HandoverAck(
        handoverId: 1,
        by: 'bob',
        at: DateTime.utc(2026, 8, 9, 6),
      ).toJson();
      expect(legacy.containsKey('version'), isFalse);
    });
  });
}
