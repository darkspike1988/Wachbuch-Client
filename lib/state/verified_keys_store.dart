import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists verified E2EE key fingerprints per server + user (R-020).
///
/// The trust decision (\"I compared this colleague's fingerprint in person\")
/// must outlive the app session, so it is stored locally on the device.
/// Only fingerprints are stored: no key material, no messages.
class VerifiedKeysStore {
  VerifiedKeysStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const _storageKey = 'wachbuch_verified_key_fingerprints';

  final SharedPreferences? _prefs;
  final Map<String, Map<String, String>> _cache = {};

  Future<Map<String, String>> _load(String baseUrl) async {
    if (_cache.containsKey(baseUrl)) return _cache[baseUrl]!;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    var all = <String, Map<String, String>>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          all = decoded.map(
            (server, users) => MapEntry(
              server,
              Map<String, String>.from(users as Map),
            ),
          );
        }
      } catch (_) {
        // Corrupt store: treat as empty rather than failing verification.
      }
    }
    _cache.addAll(all);
    return _cache[baseUrl] ?? <String, String>{};
  }

  Future<void> _persist() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_cache));
  }

  /// Returns the last verified fingerprint for [userId] on [baseUrl].
  Future<String?> fingerprintFor(String baseUrl, int userId) async {
    final users = await _load(baseUrl);
    return users[userId.toString()];
  }

  /// Returns all verified fingerprints on [baseUrl] (userId -> fingerprint).
  Future<Map<String, String>> allFor(String baseUrl) async {
    return Map<String, String>.from(await _load(baseUrl));
  }

  /// Marks a fingerprint as verified. Returns `true` when this changed a
  /// previously stored fingerprint (i.e. the key changed since verification).
  Future<bool> markVerified(String baseUrl, int userId, String fingerprint) async {
    await _load(baseUrl);
    final users = _cache[baseUrl] ??= <String, String>{};
    final key = userId.toString();
    final previous = users[key];
    users[key] = fingerprint;
    await _persist();
    return previous != null && previous != fingerprint;
  }

  Future<void> remove(String baseUrl, int userId) async {
    await _load(baseUrl);
    _cache[baseUrl]?.remove(userId.toString());
    await _persist();
  }
}
