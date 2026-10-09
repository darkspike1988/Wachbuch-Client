/// Acknowledgement that a handover was read/accepted.
/// See docs/SCHEMA-WACHALLTAG.md and contract >= 1.4.0.
///
/// An acknowledgement is bound to a specific handover *revision* (`version`).
/// `version` is `null` only for legacy acknowledgements recorded before
/// revision-bound acknowledgement existed; a `null` version must never be
/// treated as the current revision.
class HandoverAck {
  const HandoverAck({
    required this.handoverId,
    required this.by,
    required this.at,
    this.version,
  });

  factory HandoverAck.fromJson(Map<String, dynamic> json) {
    return HandoverAck(
      handoverId: _readInt(json['handover_id'] ?? json['handoverId']),
      by: (json['by'] ?? json['user'] ?? '').toString().trim(),
      at: _readDate(json['at'] ?? json['created_at']) ?? DateTime.now(),
      version: parseHandoverRevision(json['version']),
    );
  }

  final int handoverId;
  final String by;
  final DateTime at;

  /// Handover revision this acknowledgement is bound to, or `null` for a
  /// legacy acknowledgement whose revision is unknown.
  final int? version;

  Map<String, dynamic> toJson() => {
    'handover_id': handoverId,
    'by': by,
    'at': at.toUtc().toIso8601String(),
    if (version != null) 'version': version,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HandoverAck &&
          runtimeType == other.runtimeType &&
          handoverId == other.handoverId &&
          by == other.by &&
          at == other.at &&
          version == other.version;

  @override
  int get hashCode => Object.hash(handoverId, by, at, version);
}

DateTime? _readDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

int _readInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// Parses a nullable positive revision. Returns `null` for anything that is
/// not a positive integer (missing, bool, non-numeric string, fractional
/// number, zero or negative), so callers fail closed instead of guessing.
int? parseHandoverRevision(Object? value) {
  if (value is int) return value < 1 ? null : value;
  if (value is double) {
    // JSON exponent overflow can produce Infinity. Never let toInt throw or
    // clamp an oversized floating-point value into an invented revision.
    // Above 2^53-1, doubles cannot identify every integer revision exactly.
    if (!value.isFinite ||
        value < 1 ||
        value > 9007199254740991 ||
        value != value.roundToDouble()) {
      return null;
    }
    final whole = value.toInt();
    return whole < 1 ? null : whole;
  }
  final parsed = int.tryParse(value?.toString() ?? '');
  return (parsed == null || parsed < 1) ? null : parsed;
}
