import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small encrypted cache for read-only API snapshots.
///
/// It is intentionally session-scoped: the storage namespace includes a SHA-256
/// digest of server origin + app token so cached station data can never bleed
/// into another login on the same device.
abstract class ApiCache {
  Future<Map<String, dynamic>?> readJson(String key);
  Future<void> writeJson(String key, Map<String, dynamic> value);
  Future<void> clear();
}

class SecureApiCache implements ApiCache {
  SecureApiCache({
    required this.namespace,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  factory SecureApiCache.forSession({
    required String baseUrl,
    required String token,
    FlutterSecureStorage? storage,
  }) {
    final digest = sha256.convert(utf8.encode('$baseUrl|$token')).toString();
    return SecureApiCache(
      namespace: digest.substring(0, 24),
      storage: storage,
    );
  }

  final String namespace;
  final FlutterSecureStorage _storage;
  final Set<String> _knownKeys = <String>{};

  String _key(String key) => 'wachbuch_cache_${namespace}_$key';

  @override
  Future<Map<String, dynamic>?> readJson(String key) async {
    final raw = await _storage.read(key: _key(key));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      await _storage.delete(key: _key(key));
    }
    return null;
  }

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    _knownKeys.add(key);
    await _storage.write(key: _key(key), value: jsonEncode(value));
  }

  @override
  Future<void> clear() async {
    for (final key in _knownKeys) {
      await _storage.delete(key: _key(key));
    }
    _knownKeys.clear();
  }
}
