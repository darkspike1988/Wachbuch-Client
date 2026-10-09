import 'defect.dart';
import 'defect_attachment.dart';

/// One entry in a defect's append-only history.
///
/// See `GET /api/v1/defects/{id}/` in the frozen server contract (OpenAPI
/// 1.3.1): each event carries `kind`, the optional status transition and the
/// acting user, matching the documented `DefectEvent` schema.
class DefectEvent {
  const DefectEvent({
    required this.kind,
    this.fromStatus,
    this.toStatus,
    this.by = '',
    this.at,
  });

  factory DefectEvent.fromJson(Map<String, dynamic> json) {
    return DefectEvent(
      kind: (json['kind'] ?? '').toString().trim(),
      fromStatus: _readOptionalText(json['from_status'] ?? json['fromStatus']),
      toStatus: _readOptionalText(json['to_status'] ?? json['toStatus']),
      by: (json['by'] ?? '').toString().trim(),
      at: _readDate(json['at']),
    );
  }

  final String kind;
  final String? fromStatus;
  final String? toStatus;
  final String by;
  final DateTime? at;
}

/// `GET /api/v1/defects/{id}/` — the defect plus its history (at most the 100
/// most recent events) and image attachment metadata.
class DefectDetail {
  const DefectDetail({
    required this.defect,
    this.events = const [],
    this.attachments = const [],
  });

  factory DefectDetail.fromJson(Map<String, dynamic> json) {
    return DefectDetail(
      defect: Defect.fromJson(json),
      events: _readEvents(json['events']),
      attachments: _readAttachments(json['attachments']),
    );
  }

  final Defect defect;
  final List<DefectEvent> events;
  final List<DefectAttachment> attachments;
}

List<DefectEvent> _readEvents(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((entry) => DefectEvent.fromJson(Map<String, dynamic>.from(entry)))
      .toList(growable: false);
}

List<DefectAttachment> _readAttachments(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((entry) => DefectAttachment.fromJson(Map<String, dynamic>.from(entry)))
      .toList(growable: false);
}

String? _readOptionalText(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _readDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}
