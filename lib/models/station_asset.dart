/// Vehicle / device / key status on a station — see docs/SCHEMA-WACHALLTAG.md.
class StationAsset {
  const StationAsset({
    required this.id,
    required this.label,
    this.kind = 'device',
    this.status = 'ready',
    this.note = '',
    this.inspectionIntervalDays,
    this.lastInspectedAt,
    this.nextInspectionDate,
    this.inspectionState = 'none',
  });

  factory StationAsset.fromJson(Map<String, dynamic> json) {
    return StationAsset(
      id: (json['id'] ?? '').toString().trim(),
      label: (json['label'] ?? json['name'] ?? '').toString().trim(),
      kind: _readKind(json['kind']),
      status: _readStatus(json['status']),
      note: (json['note'] ?? '').toString().trim(),
      inspectionIntervalDays: json['inspection_interval_days'] is int
          ? json['inspection_interval_days'] as int
          : int.tryParse('${json['inspection_interval_days'] ?? ''}'),
      lastInspectedAt: _readDate(json['last_inspected_at']),
      nextInspectionDate: _readDate(json['next_inspection_date']),
      inspectionState: (json['inspection_state'] ?? 'none').toString(),
    );
  }

  final String id;
  final String label;
  final String kind;
  final String status;
  final String note;
  final int? inspectionIntervalDays;
  final DateTime? lastInspectedAt;
  final DateTime? nextInspectionDate;
  final String inspectionState;

  bool get isReady => status == 'ready';

  bool get needsAttention =>
      status == 'limited' || status == 'oob' || status == 'workshop';

  bool get inspectionNeedsAttention =>
      inspectionState == 'overdue' ||
      inspectionState == 'due_soon' ||
      inspectionState == 'unknown';

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'kind': kind,
        'status': status,
        'note': note,
      };

  StationAsset copyWith({
    String? id,
    String? label,
    String? kind,
    String? status,
    String? note,
  }) {
    return StationAsset(
      id: id ?? this.id,
      label: label ?? this.label,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      note: note ?? this.note,
      inspectionIntervalDays: inspectionIntervalDays,
      lastInspectedAt: lastInspectedAt,
      nextInspectionDate: nextInspectionDate,
      inspectionState: inspectionState,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StationAsset &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

String _readKind(Object? value) {
  final raw = value?.toString().trim().toLowerCase() ?? '';
  return switch (raw) {
    'vehicle' => 'vehicle',
    'key' => 'key',
    _ => 'device',
  };
}

String _readStatus(Object? value) {
  final raw = value?.toString().trim().toLowerCase() ?? '';
  return switch (raw) {
    'limited' => 'limited',
    'oob' || 'out_of_order' || 'außer_betrieb' => 'oob',
    'workshop' || 'werkstatt' => 'workshop',
    _ => 'ready',
  };
}

DateTime? _readDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

/// One append-only inspection record on a device.
class AssetInspectionRecord {
  const AssetInspectionRecord({
    required this.result,
    required this.note,
    required this.by,
    this.at,
  });

  factory AssetInspectionRecord.fromJson(Map<String, dynamic> json) => AssetInspectionRecord(
        result: (json['result'] ?? 'ok').toString(),
        note: (json['note'] ?? '').toString(),
        by: (json['by'] ?? '').toString(),
        at: _readDate(json['at']),
      );

  final String result;
  final String note;
  final String by;
  final DateTime? at;

  bool get isDefect => result == 'defect';
}

class OpenDefectRef {
  const OpenDefectRef({required this.id, required this.title, required this.priority});

  factory OpenDefectRef.fromJson(Map<String, dynamic> json) => OpenDefectRef(
        id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
        title: (json['title'] ?? '').toString(),
        priority: (json['priority'] ?? 'normal').toString(),
      );

  final int id;
  final String title;
  final String priority;
}

/// Device card = asset + inspection history + open defects (QR target).
class AssetCard {
  const AssetCard({
    required this.asset,
    required this.inspections,
    required this.openDefects,
  });

  factory AssetCard.fromJson(Map<String, dynamic> json) => AssetCard(
        asset: StationAsset.fromJson(json),
        inspections: (json['inspections'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => AssetInspectionRecord.fromJson(Map<String, dynamic>.from(m)))
            .toList(growable: false),
        openDefects: (json['open_defects'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => OpenDefectRef.fromJson(Map<String, dynamic>.from(m)))
            .toList(growable: false),
      );

  final StationAsset asset;
  final List<AssetInspectionRecord> inspections;
  final List<OpenDefectRef> openDefects;
}
