import 'dart:typed_data';

import 'package:image/image.dart' as img;

class SanitizedUploadImage {
  const SanitizedUploadImage({
    required this.bytes,
    required this.filename,
  });

  final Uint8List bytes;
  final String filename;

  String get contentType => 'image/jpeg';
}

/// Decodes the selected image to pixels and creates a fresh JPEG for upload.
///
/// The source EXIF/GPS, embedded text and ICC metadata are explicitly removed.
/// Orientation is baked into the pixel data before EXIF is cleared. Only the
/// first decoded frame is uploaded; defect photos are deliberately not an
/// animation/document transport channel.
SanitizedUploadImage? sanitizeDefectPhoto(
  Uint8List sourceBytes, {
  required String sourceFilename,
  int quality = 82,
}) {
  final decoded = img.decodeImage(sourceBytes, frame: 0);
  if (decoded == null || !decoded.isValid) return null;

  final oriented = img.bakeOrientation(decoded);
  oriented.exif.clear();
  oriented.iccProfile = null;
  oriented.textData = null;

  final jpeg = img.JpegEncoder(quality: quality).encode(
    oriented,
    singleFrame: true,
  );
  if (jpeg.isEmpty) return null;

  final base = _safeBaseName(sourceFilename);
  return SanitizedUploadImage(
    bytes: jpeg,
    filename: '$base.jpg',
  );
}

String _safeBaseName(String sourceFilename) {
  var value = sourceFilename.replaceAll('\\', '/').split('/').last.trim();
  final dot = value.lastIndexOf('.');
  if (dot > 0) value = value.substring(0, dot);
  value = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
  value = value.replaceAll(RegExp(r'-+'), '-');
  value = value.replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
  if (value.isEmpty) return 'mangel-foto';
  return value.length <= 120 ? value : value.substring(0, 120);
}
