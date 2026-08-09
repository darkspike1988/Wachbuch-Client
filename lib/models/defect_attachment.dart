/// Metadata for a defect attachment / Beleg (Phase 3).
///
/// Demo and future servers share this shape; binary upload is optional until
/// the server implements multipart. See `docs/openapi-wachalltag.yaml`.
class DefectAttachment {
  const DefectAttachment({
    required this.id,
    required this.name,
    this.contentType = 'application/octet-stream',
    this.sizeBytes = 0,
    this.createdAt,
    this.localOnly = false,
  });

  factory DefectAttachment.fromJson(Map<String, dynamic> json) {
    return DefectAttachment(
      id: (json['id'] ?? '').toString().trim(),
      name: (json['name'] ?? json['filename'] ?? '').toString().trim(),
      contentType:
          (json['content_type'] ?? json['contentType'] ?? 'application/octet-stream')
              .toString()
              .trim(),
      sizeBytes: _readInt(json['size_bytes'] ?? json['size']),
      createdAt: _readDate(json['created_at'] ?? json['createdAt']),
      localOnly: json['local_only'] == true || json['localOnly'] == true,
    );
  }

  final String id;
  final String name;
  final String contentType;
  final int sizeBytes;
  final DateTime? createdAt;

  /// True for demo placeholders that never left the device.
  final bool localOnly;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'content_type': contentType,
        'size_bytes': sizeBytes,
        if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
        if (localOnly) 'local_only': true,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefectAttachment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

int _readInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _readDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}
