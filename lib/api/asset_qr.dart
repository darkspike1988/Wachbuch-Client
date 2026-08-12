/// Helpers for device (asset) QR codes.
///
/// A device label QR encodes the station-unique asset id, optionally with a
/// `wachbuch-asset:` prefix or as a `.../assets/<id>/` URL. The station scope
/// comes from the API token, so the id alone is sufficient.
library;

final RegExp _assetIdPattern = RegExp(r'^[a-z0-9-]{1,64}$');

/// Payload to encode into a printed device QR code.
String assetQrPayload(String assetId) => 'wachbuch-asset:$assetId';

/// Parse a scanned QR value into an asset id, or throw [FormatException].
String parseAssetQr(String raw) {
  var value = raw.trim();
  const prefix = 'wachbuch-asset:';
  if (value.toLowerCase().startsWith(prefix)) {
    value = value.substring(prefix.length).trim();
  } else {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.pathSegments.contains('assets')) {
      final index = uri.pathSegments.indexOf('assets');
      if (index + 1 < uri.pathSegments.length) {
        value = uri.pathSegments[index + 1].trim();
      }
    }
  }
  if (!_assetIdPattern.hasMatch(value)) {
    throw const FormatException('Kein gueltiger Geraete-Code.');
  }
  return value;
}
