/// Parse and normalize Wachbuch server addresses from typed input or QR payloads.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wachbuch_mobile/api/client.dart';

/// Extracts a Wachbuch server origin from typed text or QR content.
///
/// Accepted forms (Google Play / Nextcloud-style self-host setup):
/// - `https://wache.example.org`
/// - `wache.example.org` (https assumed)
/// - `https://wache.example.org/anmelden/` (path stripped to origin)
/// - JSON: `{"url":"https://…"}` or `{"server":"https://…"}`
/// - `wachbuch://connect?url=https%3A%2F%2F…`
String parseServerAddress(String raw, {bool allowInsecure = kDebugMode}) {
  var value = raw.trim();
  if (value.isEmpty) {
    throw ArgumentError('Adresse fehlt.');
  }

  if (value.startsWith('{')) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        throw ArgumentError('Ungültiger QR-Code.');
      }
      final url = decoded['url'] ?? decoded['server'] ?? decoded['baseUrl'];
      if (url is! String || url.trim().isEmpty) {
        throw ArgumentError('Server-Adresse fehlt im QR-Code.');
      }
      value = url.trim();
    } on FormatException {
      throw ArgumentError('Ungültiger QR-Code.');
    }
  }

  final candidate = Uri.tryParse(value);
  if (candidate == null) {
    throw ArgumentError('Ungültige Server-Adresse.');
  }
  if (candidate.scheme.isNotEmpty &&
      candidate.scheme != 'http' &&
      candidate.scheme != 'https' &&
      candidate.scheme != 'wachbuch') {
    throw ArgumentError('Nur HTTP- oder HTTPS-Adressen werden unterstützt.');
  }

  if (candidate.scheme == 'wachbuch') {
    if (candidate.host != 'connect' && !candidate.path.contains('connect')) {
      throw ArgumentError('Ungültiger Wachbuch-Link.');
    }
    final url = candidate.queryParameters['url'];
    if (url == null || url.trim().isEmpty) {
      throw ArgumentError('Server-Adresse fehlt im Wachbuch-Link.');
    }
    value = url.trim();
  }

  try {
    final normalized = normalizeServerUrl(value);
    final uri = Uri.parse(normalized);
    if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      throw ArgumentError('Ungültige Server-Adresse.');
    }
    if (uri.scheme == 'http' && !allowInsecure) {
      throw ArgumentError('Für diese App ist eine HTTPS-Adresse erforderlich.');
    }
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  } on FormatException {
    throw ArgumentError('Ungültige Server-Adresse.');
  }
}
