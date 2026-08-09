/// HTTP client for Wachbuch `/api/v1/` (Paperless/Nextcloud-style token auth).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:wachbuch_mobile/api/wachalltag_paths.dart';
import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/handover_ack.dart';
import 'package:wachbuch_mobile/models/inventory_item.dart';
import 'package:wachbuch_mobile/models/kaffeekasse.dart';
import 'package:wachbuch_mobile/models/kalender_entry.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';

typedef WachbuchApiFactory = WachbuchApi Function(String baseUrl);

WachbuchApi defaultWachbuchApiFactory(String baseUrl) {
  return WachbuchApi(baseUrl: baseUrl);
}

/// Retries [fn] on transient network failures (timeouts, connection errors,
/// 5xx responses) with exponential backoff. Non-retryable errors are rethrown
/// immediately.
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
}) async {
  Duration delay = initialDelay;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } on TimeoutException {
      if (attempt == maxAttempts) rethrow;
    } on http.ClientException {
      if (attempt == maxAttempts) rethrow;
    } on ApiException catch (error) {
      final isConnectionError = error.statusCode == 0;
      // 501 = Not Implemented / optional module — do not burn retries.
      final isServerError =
          error.statusCode >= 500 && error.statusCode != 501;
      if (!isConnectionError && !isServerError) rethrow;
      if (attempt == maxAttempts) rethrow;
    }
    await Future.delayed(delay);
    delay *= 2;
  }
  throw Exception('Unreachable');
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.code});

  final int statusCode;
  final String message;
  final String? code;

  bool get isMfaRequired =>
      statusCode == 403 && (code == 'mfa_required' || message.contains('MFA'));

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class AuthToken {
  const AuthToken({required this.value, this.expiresAt});

  final String value;
  final DateTime? expiresAt;
}

class WachbuchApi {
  WachbuchApi({
    required this.baseUrl,
    this.token,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  /// Origin only, e.g. https://wache.example.org (no trailing slash).
  final String baseUrl;
  final String? token;
  final Duration requestTimeout;
  final http.Client _client;

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path');
  }

  Map<String, String> _headers({bool auth = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth && token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Token $token';
    }
    return headers;
  }

  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(requestTimeout);
    } on TimeoutException {
      throw ApiException(
        0,
        'Zeitlimit überschritten. Bitte Server und Verbindung prüfen.',
      );
    } on http.ClientException catch (error) {
      throw ApiException(0, 'Netzwerkfehler: ${error.message}');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        } else {
          throw const FormatException('JSON object expected');
        }
      } on FormatException {
        if (response.statusCode >= 500) {
          throw ApiException(
            response.statusCode,
            'Serverfehler (${response.statusCode}). Bitte später erneut versuchen.',
          );
        }
        throw ApiException(
          response.statusCode,
          'Der Server hat eine ungültige Antwort gesendet.',
        );
      }
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        (body['error'] as String?) ??
            'Anfrage fehlgeschlagen (${response.statusCode})',
        code: body['code'] as String?,
      );
    }
    return body;
  }

  /// GET /api/v1/ – discovery without auth.
  Future<Map<String, dynamic>> discover() async {
    return _withRetry(() async {
      final response = await _send(
        _client.get(_uri('/api/v1/'), headers: _headers(auth: false)),
      );
      final body = _decode(response);
      ensureWachbuchDiscovery(body);
      return body;
    });
  }

  /// POST /api/v1/token/
  Future<AuthToken> obtainToken({
    required String username,
    required String password,
    String label = 'Mobile App',
  }) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/token/'),
          headers: _headers(auth: false),
          body: jsonEncode({
            'username': username,
            'password': password,
            'label': label,
          }),
        ),
      );
      final body = _decode(response);
      final value = body['token'] as String?;
      if (value == null || value.isEmpty) {
        throw ApiException(response.statusCode, 'Kein Token in der Antwort.');
      }
      return AuthToken(
        value: value,
        expiresAt: _parseExpiresAt(body['expires_at']),
      );
    });
  }

  /// GET /api/v1/me/
  Future<Map<String, dynamic>> me() async {
    return _withRetry(() async {
      final response = await _send(
        _client.get(_uri('/api/v1/me/'), headers: _headers()),
      );
      return _decode(response);
    });
  }

  /// GET /api/v1/handovers/
  Future<List<Map<String, dynamic>>> handovers() async {
    return _withRetry(() async {
      final response = await _send(
        _client.get(_uri('/api/v1/handovers/'), headers: _headers()),
      );
      final body = _decode(response);
      final results = body['results'];
      if (results is! List) {
        return <Map<String, dynamic>>[];
      }
      return results
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    });
  }

  /// GET /api/v1/handovers/{id}/
  Future<Map<String, dynamic>> handoverDetail(int id) async {
    return _withRetry(() async {
      final response = await _send(
        _client.get(_uri('/api/v1/handovers/$id/'), headers: _headers()),
      );
      return _decode(response);
    });
  }

  /// GET /api/v1/kalender/ — Wachenkalender (Modul `calendar`).
  Future<List<KalenderEntry>> kalender() async {
    return _withRetry(() async {
      final response = await _send(
        _client.get(_uri('/api/v1/kalender/'), headers: _headers()),
      );
      final body = _decode(response);
      return _readList(body)
          .map(KalenderEntry.fromJson)
          .toList(growable: false);
    });
  }

  /// GET /api/v1/kaffeekasse/ — Kassenstand und Ledger (Modul `coffee`).
  Future<Kaffeekasse> kaffeekasse() async {
    return _withRetry(() async {
      final response = await _send(
        _client.get(_uri('/api/v1/kaffeekasse/'), headers: _headers()),
      );
      final body = _decode(response);
      return Kaffeekasse.fromJson(body);
    });
  }

  /// GET /api/v1/checklisten/ — Checklisten (Modul `checklists`).
  Future<List<Checklist>> checklisten() async {
    return _withRetry(() async {
      final response = await _send(
        _client.get(_uri('/api/v1/checklisten/'), headers: _headers()),
      );
      final body = _decode(response);
      return _readList(body).map(Checklist.fromJson).toList(growable: false);
    });
  }

  /// POST /api/v1/checklisten/{id}/abschluss/ — Checkliste abschließen (append-only).
  Future<Checklist> checklisteAbschluss(int id) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri('/api/v1/checklisten/$id/abschluss/'),
          headers: _headers(),
        ),
      );
      final body = _decode(response);
      if (body.isEmpty) {
        return Checklist(id: id, title: '', completed: true);
      }
      return Checklist.fromJson({...body, 'completed': true});
    });
  }

  /// GET /api/v1/defects/ — Mängel (Modul `defects`, Contract: SCHEMA-WACHALLTAG).
  Future<List<Defect>> defects() async {
    return _withRetry(() async {
      final response = await _send(
        _client.get(_uri(WachalltagPaths.defects), headers: _headers()),
      );
      final body = _decode(_requireModule(response, 'Mängel'));
      return _readList(body).map(Defect.fromJson).toList(growable: false);
    });
  }

  /// POST /api/v1/defects/ — Mangel anlegen (Welle 2 / Phase 1).
  Future<Defect> createDefect(Map<String, dynamic> payload) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri(WachalltagPaths.defects),
          headers: _headers(),
          body: jsonEncode(payload),
        ),
      );
      final body = _decode(_requireModule(response, 'Mängel'));
      return Defect.fromJson(body);
    });
  }

  /// POST /api/v1/defects/{id}/status/ — Statuswechsel (append-only).
  Future<Defect> updateDefectStatus(int id, String status) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri(WachalltagPaths.defectStatus(id)),
          headers: _headers(),
          body: jsonEncode({'status': status}),
        ),
      );
      final body = _decode(_requireModule(response, 'Mängel'));
      return Defect.fromJson(body.isEmpty ? {'id': id, 'status': status} : body);
    });
  }

  /// GET /api/v1/assets/ — Fahrzeug-/Gerätestatus (Modul `assets`).
  Future<List<StationAsset>> assets() async {
    return _withRetry(() async {
      final response = await _send(
        _client.get(_uri(WachalltagPaths.assets), headers: _headers()),
      );
      final body = _decode(_requireModule(response, 'Geräte'));
      return _readList(body)
          .map(StationAsset.fromJson)
          .toList(growable: false);
    });
  }

  /// POST /api/v1/assets/{id}/status/ — Asset-Status setzen.
  Future<StationAsset> updateAssetStatus(
    String id, {
    required String status,
    String note = '',
  }) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri(WachalltagPaths.assetStatus(id)),
          headers: _headers(),
          body: jsonEncode({
            'status': status,
            if (note.isNotEmpty) 'note': note,
          }),
        ),
      );
      final body = _decode(_requireModule(response, 'Geräte'));
      return StationAsset.fromJson(
        body.isEmpty ? {'id': id, 'status': status, 'note': note} : body,
      );
    });
  }

  /// GET /api/v1/inventory/ — Schlüssel-/Pool-Geräte (Modul `inventory`).
  Future<List<InventoryItem>> inventory() async {
    return _withRetry(() async {
      final response = await _send(
        _client.get(_uri(WachalltagPaths.inventory), headers: _headers()),
      );
      final body = _decode(_requireModule(response, 'Inventar'));
      return _readList(body)
          .map(InventoryItem.fromJson)
          .toList(growable: false);
    });
  }

  /// POST /api/v1/inventory/{id}/checkout/
  Future<InventoryItem> inventoryCheckout(String id) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri(WachalltagPaths.inventoryCheckout(id)),
          headers: _headers(),
        ),
      );
      final body = _decode(_requireModule(response, 'Inventar'));
      return InventoryItem.fromJson(body.isEmpty ? {'id': id} : body);
    });
  }

  /// POST /api/v1/inventory/{id}/checkin/
  Future<InventoryItem> inventoryCheckin(String id) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri(WachalltagPaths.inventoryCheckin(id)),
          headers: _headers(),
        ),
      );
      final body = _decode(_requireModule(response, 'Inventar'));
      return InventoryItem.fromJson(body.isEmpty ? {'id': id} : body);
    });
  }

  /// GET /api/v1/handovers/{id}/acks/
  Future<List<HandoverAck>> handoverAcks(int id) async {
    return _withRetry(() async {
      final response = await _send(
        _client.get(
          _uri(WachalltagPaths.handoverAcks(id)),
          headers: _headers(),
        ),
      );
      final body = _decode(_requireModule(response, 'Quittierung'));
      return _readList(body).map(HandoverAck.fromJson).toList(growable: false);
    });
  }

  /// POST /api/v1/handovers/{id}/ack/ — idempotent pro Benutzer.
  Future<HandoverAck> acknowledgeHandover(int id) async {
    return _withRetry(() async {
      final response = await _send(
        _client.post(
          _uri(WachalltagPaths.handoverAck(id)),
          headers: _headers(),
          body: jsonEncode(const <String, dynamic>{}),
        ),
      );
      final body = _decode(_requireModule(response, 'Quittierung'));
      if (body.isEmpty) {
        return HandoverAck(handoverId: id, by: '', at: DateTime.now());
      }
      return HandoverAck.fromJson({...body, 'handover_id': body['handover_id'] ?? id});
    });
  }

  /// Turns module-disabled 404 into a clear, non-retryable ApiException.
  http.Response _requireModule(http.Response response, String label) {
    if (response.statusCode == 404) {
      throw ApiException(
        404,
        '$label-Modul auf diesem Server nicht verfügbar.',
      );
    }
    return response;
  }

  /// Optional modules that are not installed on older servers.
  static bool isModuleUnavailable(ApiException error) =>
      error.statusCode == 404 || error.statusCode == 501;

  List<Map<String, dynamic>> _readList(Map<String, dynamic> body) {
    final results = body['results'] ?? body['entries'] ?? body['termine'];
    if (results is! List) return const [];
    return results
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  void close() {
    _client.close();
  }

  WachbuchApi copyWithToken(String newToken) {
    return WachbuchApi(
      baseUrl: baseUrl,
      token: newToken,
      client: _client,
      requestTimeout: requestTimeout,
    );
  }
}

/// Validates that a discovery payload looks like a Wachbuch API root.
void ensureWachbuchDiscovery(Map<String, dynamic> body) {
  final endpoints = body['endpoints'];
  final hasTokenEndpoint =
      endpoints is Map &&
      (endpoints.containsKey('token') || endpoints.containsKey('anmeldung'));
  final ok = body['ok'] == true || body['ok'] == 'true';
  final hasVersion =
      body['api_version'] != null ||
      body['version'] != null ||
      body['name'] != null;
  if (!ok && !hasTokenEndpoint && !hasVersion) {
    throw ApiException(
      0,
      'Die Adresse antwortet nicht wie ein Wachbuch-Server (/api/v1/).',
    );
  }
}

DateTime? _parseExpiresAt(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

String normalizeServerUrl(String input) {
  var value = input.trim();
  if (value.isEmpty) {
    throw ArgumentError('Server-URL fehlt.');
  }
  if (!value.startsWith('http://') && !value.startsWith('https://')) {
    value = 'https://$value';
  }
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

/// German labels for station module keys from `/me/`.
String moduleLabel(String key) {
  const labels = <String, String>{
    'calendar': 'Kalender',
    'birthdays': 'Geburtstage',
    'coffee': 'Kaffeekasse',
    'feeds': 'Meldungen & Verkehr',
    'checklists': 'Checklisten',
    'messaging': 'Nachrichten',
    'tasks': 'Aufgaben',
    'defects': 'Mängel',
    'assets': 'Geräte',
    'inventory': 'Schlüssel & Pools',
  };
  return labels[key] ?? key;
}
