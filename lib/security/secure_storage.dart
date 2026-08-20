import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_web/flutter_secure_storage_web.dart';

/// Canonical secure-storage configuration for Wachbuch credentials and cache.
///
/// Android deliberately stages the 9.x -> 10.x migration before any future
/// move to v11. Version 10 uses RSA-OAEP/SHA-256 key wrapping with AES-GCM by
/// default and can migrate old cipher storage. Backup markers make migration
/// crash-resistant for existing production credentials.
///
/// Web support uses flutter_secure_storage_web as a fallback.
FlutterSecureStorage createWachbuchSecureStorage() {
  if (kIsWeb) {
    return FlutterSecureStorageWeb();
  }
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(
      migrateOnAlgorithmChange: true,
      migrateWithBackup: true,
    ),
  );
}
