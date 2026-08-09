import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';

/// Encrypted (platform keystore) read-only snapshot of Wachalltag lists.
///
/// v1 is intentionally read-only offline — no blind writes when reconnecting.
class OfflineReadCache {
  OfflineReadCache({
    required this.serverUrl,
    FlutterSecureStorage? secureStorage,
  })  : _secure = secureStorage ?? const FlutterSecureStorage(),
        _memory = null;

  /// In-memory cache for tests (no platform channel / timers).
  OfflineReadCache.memory({required this.serverUrl})
      : _secure = null,
        _memory = <String, String>{};

  static const _payloadKey = 'wachbuch_offline_read_cache_v1';
  static const _legacyKeys = <String>[
    'wachbuch_offline_handovers',
    'wachbuch_offline_defects',
    'wachbuch_offline_assets',
    'wachbuch_offline_updated_at',
  ];

  final String serverUrl;
  final FlutterSecureStorage? _secure;
  final Map<String, String>? _memory;

  /// Persists the last successful online snapshot for this [serverUrl].
  Future<void> write({
    List<Map<String, dynamic>>? handovers,
    List<Defect>? defects,
    List<StationAsset>? assets,
    DateTime? updatedAt,
  }) async {
    try {
      final existing = await read();
      final payload = {
        'server_url': serverUrl,
        'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'handovers': handovers ?? existing?.handovers ?? const [],
        'defects': (defects ?? existing?.defects ?? const [])
            .map((item) => item.toJson())
            .toList(growable: false),
        'assets': (assets ?? existing?.assets ?? const [])
            .map((item) => item.toJson())
            .toList(growable: false),
      };
      await _writeRaw(_payloadKey, jsonEncode(payload));
    } catch (_) {
      // Secure storage may be unavailable (locked device).
    }
  }

  Future<OfflineSnapshot?> read() async {
    try {
      final raw = await _readRaw(_payloadKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final cachedUrl = (map['server_url'] ?? '').toString();
      if (cachedUrl.isNotEmpty && cachedUrl != serverUrl) return null;
      final updatedAt = DateTime.tryParse(
            (map['updated_at'] ?? '').toString(),
          )?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final handovers = _readMapList(map['handovers']);
      final defects = _readMapList(map['defects'])
          .map(Defect.fromJson)
          .toList(growable: false);
      final assets = _readMapList(map['assets'])
          .map(StationAsset.fromJson)
          .toList(growable: false);
      return OfflineSnapshot(
        serverUrl: cachedUrl.isEmpty ? serverUrl : cachedUrl,
        updatedAt: updatedAt,
        handovers: handovers,
        defects: defects,
        assets: assets,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _deleteRaw(_payloadKey);
      for (final key in _legacyKeys) {
        await _deleteRaw(key);
      }
    } catch (_) {
      // Best-effort invalidation.
    }
  }

  /// Drops every offline snapshot key (logout / server switch).
  static Future<void> clearAll([FlutterSecureStorage? secureStorage]) async {
    try {
      final secure = secureStorage ?? const FlutterSecureStorage();
      await secure.delete(key: _payloadKey);
      for (final key in _legacyKeys) {
        await secure.delete(key: key);
      }
    } catch (_) {
      // Best-effort invalidation.
    }
  }

  Future<void> _writeRaw(String key, String value) async {
    final memory = _memory;
    if (memory != null) {
      memory[key] = value;
      return;
    }
    await _secure!.write(key: key, value: value);
  }

  Future<String?> _readRaw(String key) async {
    final memory = _memory;
    if (memory != null) return memory[key];
    return _secure!.read(key: key);
  }

  Future<void> _deleteRaw(String key) async {
    final memory = _memory;
    if (memory != null) {
      memory.remove(key);
      return;
    }
    await _secure!.delete(key: key);
  }
}

class OfflineSnapshot {
  const OfflineSnapshot({
    required this.serverUrl,
    required this.updatedAt,
    this.handovers = const [],
    this.defects = const [],
    this.assets = const [],
  });

  final String serverUrl;
  final DateTime updatedAt;
  final List<Map<String, dynamic>> handovers;
  final List<Defect> defects;
  final List<StationAsset> assets;
}

List<Map<String, dynamic>> _readMapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
