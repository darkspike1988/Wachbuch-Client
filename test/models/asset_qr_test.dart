import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/asset_qr.dart';

void main() {
  group('parseAssetQr', () {
    test('accepts the prefixed payload', () {
      expect(parseAssetQr('wachbuch-asset:atem-1'), 'atem-1');
    });

    test('accepts a plain slug', () {
      expect(parseAssetQr('rtw-2'), 'rtw-2');
    });

    test('extracts the id from an assets URL', () {
      expect(parseAssetQr('https://wache.example.org/api/v1/assets/dlk-1/'), 'dlk-1');
    });

    test('round-trips the payload builder', () {
      expect(parseAssetQr(assetQrPayload('funk-3')), 'funk-3');
    });

    test('rejects invalid codes', () {
      expect(() => parseAssetQr('Not A Code!'), throwsFormatException);
      expect(() => parseAssetQr(''), throwsFormatException);
    });
  });
}
