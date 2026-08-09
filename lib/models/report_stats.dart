import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';

/// Client-side aggregation for the Auswertung screen (no report API).
class ReportStats {
  const ReportStats({
    required this.openDefects,
    required this.byOwner,
    required this.readyAssets,
    required this.totalAssets,
    required this.overdueChecks,
  });

  factory ReportStats.from({
    required List<Defect> defects,
    required List<StationAsset> assets,
    required List<Checklist> checklists,
  }) {
    final open = defects.where((item) => item.isOpen).toList(growable: false);
    final byOwner = <String, int>{};
    for (final defect in open) {
      final key = defect.owner.trim().isEmpty ? '—' : defect.owner.trim();
      byOwner[key] = (byOwner[key] ?? 0) + 1;
    }
    final ready = assets.where((item) => item.isReady).length;
    final overdue = checklists.where((item) => !item.completed && item.overdue).length;
    return ReportStats(
      openDefects: open,
      byOwner: Map.unmodifiable(byOwner),
      readyAssets: ready,
      totalAssets: assets.length,
      overdueChecks: overdue,
    );
  }

  final List<Defect> openDefects;
  final Map<String, int> byOwner;
  final int readyAssets;
  final int totalAssets;
  final int overdueChecks;

  int get ampQuotePercent {
    if (totalAssets == 0) return 0;
    return ((readyAssets / totalAssets) * 100).round();
  }
}
