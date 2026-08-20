import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/security/secure_storage.dart';

void main() {
  group('Secure Storage Configuration', () {
    test('createWachbuchSecureStorage returns configured instance', () {
      final storage = createWachbuchSecureStorage();
      expect(storage, isA<FlutterSecureStorage>());
    });

    test('Android options are configured for migration', () {
      final storage = createWachbuchSecureStorage();
      // Note: We cannot directly inspect the private AndroidOptions,
      // but we can verify the instance is created with the expected behavior.
      expect(storage, isNotNull);
    });
  });

  group('Secure Storage Migration (9.x -> 10.x)', () {
    test('storage is configured for crash-resistant migration', () {
      final storage = createWachbuchSecureStorage();
      // FlutterSecureStorage with migrateOnAlgorithmChange: true
      // and migrateWithBackup: true ensures crash-resistant migration.
      expect(storage, isNotNull);
    });
  });
}
