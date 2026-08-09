import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/report_stats.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';

void main() {
  test('ReportStats aggregates open defects, amp quote and overdue checks', () {
    final stats = ReportStats.from(
      defects: const [
        Defect(id: 1, title: 'A', status: 'open', owner: 'Anna'),
        Defect(id: 2, title: 'B', status: 'done', owner: 'Anna'),
        Defect(id: 3, title: 'C', status: 'waiting', owner: ''),
      ],
      assets: const [
        StationAsset(id: '1', label: 'RTW', status: 'ready'),
        StationAsset(id: '2', label: 'NEF', status: 'limited'),
      ],
      checklists: [
        const Checklist(id: 1, title: 'A', overdue: true),
        const Checklist(id: 2, title: 'B', overdue: true, completed: true),
        const Checklist(id: 3, title: 'C'),
      ],
    );

    expect(stats.openDefects.length, 2);
    expect(stats.byOwner['Anna'], 1);
    expect(stats.byOwner['—'], 1);
    expect(stats.ampQuotePercent, 50);
    expect(stats.overdueChecks, 1);
  });
}
