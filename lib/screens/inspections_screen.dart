import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';
import 'package:wachbuch_mobile/screens/asset_qr_scan_screen.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/layout.dart';

String inspectionStateLabel(AppLocalizations l, String state) => switch (state) {
      'overdue' => l.inspectionStateOverdue,
      'due_soon' => l.inspectionStateDueSoon,
      'unknown' => l.inspectionStateUnknown,
      'ok' => l.inspectionStateOk,
      _ => l.inspectionStateNone,
    };

Color inspectionStateColor(ColorScheme scheme, String state) => switch (state) {
      'overdue' => scheme.errorContainer,
      'due_soon' => scheme.tertiaryContainer,
      'unknown' => scheme.secondaryContainer,
      _ => scheme.surfaceContainerHighest,
    };

String _formatDate(DateTime? date, AppLocalizations l) {
  if (date == null) return l.inspectionNever;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}';
}

/// List of due / overdue inspections (reminder surface).
class DueInspectionsScreen extends StatefulWidget {
  const DueInspectionsScreen({super.key, required this.api});

  final WachbuchApi api;

  @override
  State<DueInspectionsScreen> createState() => _DueInspectionsScreenState();
}

class _DueInspectionsScreenState extends State<DueInspectionsScreen> {
  bool _loading = true;
  String? _error;
  List<StationAsset> _due = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final due = await widget.api.dueInspections();
      if (!mounted) return;
      setState(() {
        _due = due;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  void _openCard(String assetId, String title) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AssetCardScreen(api: widget.api, assetId: assetId, title: title),
    )).then((_) => _reload());
  }

  Future<void> _scan() async {
    final assetId = await openAssetQrScanner(context);
    if (assetId != null && mounted) _openCard(assetId, assetId);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.inspectionsTitle),
        actions: [
          IconButton(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: l.inspectionScanQr,
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: AppLayout.contentMaxWidth(width)),
          child: _body(context, l),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l) {
    if (_loading && _due.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          if (_due.isEmpty && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Center(child: Text(l.inspectionsEmpty)),
            )
          else
            for (final asset in _due)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.build_circle_outlined),
                  title: Text(asset.label),
                  subtitle: Text(
                    '${l.inspectionNext}: ${_formatDate(asset.nextInspectionDate, l)}',
                  ),
                  trailing: _StateChip(state: asset.inspectionState),
                  onTap: () => _openCard(asset.id, asset.label),
                ),
              ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});
  final String state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: inspectionStateColor(scheme, state),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(inspectionStateLabel(l, state),
          style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

/// Device card: details, inspection history, open defects, record + schedule.
class AssetCardScreen extends StatefulWidget {
  const AssetCardScreen({
    super.key,
    required this.api,
    required this.assetId,
    required this.title,
  });

  final WachbuchApi api;
  final String assetId;
  final String title;

  @override
  State<AssetCardScreen> createState() => _AssetCardScreenState();
}

class _AssetCardScreenState extends State<AssetCardScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  AssetCard? _card;
  final _noteController = TextEditingController();
  final _intervalController = TextEditingController();
  String _result = 'ok';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final card = await widget.api.assetCard(widget.assetId);
      if (!mounted) return;
      setState(() {
        _card = card;
        _intervalController.text =
            card.asset.inspectionIntervalDays?.toString() ?? '';
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _record() async {
    setState(() => _busy = true);
    try {
      await widget.api.recordInspection(
        widget.assetId,
        result: _result,
        note: _noteController.text.trim(),
      );
      _noteController.clear();
      await _reload();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveInterval() async {
    final raw = _intervalController.text.trim();
    final days = raw.isEmpty ? null : int.tryParse(raw);
    setState(() => _busy = true);
    try {
      await widget.api.setInspectionSchedule(widget.assetId, days);
      await _reload();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: AppLayout.contentMaxWidth(width)),
          child: _body(context, l),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l) {
    if (_loading && _card == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_card == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorBanner(message: _error ?? l.inspectionsEmpty),
      );
    }
    final card = _card!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) ...[
          ErrorBanner(message: _error!),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: Text(card.asset.label,
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            _StateChip(state: card.asset.inspectionState),
          ],
        ),
        const SizedBox(height: 8),
        Text('${l.inspectionLast}: ${_formatDate(card.asset.lastInspectedAt, l)}'),
        Text('${l.inspectionNext}: ${_formatDate(card.asset.nextInspectionDate, l)}'),
        const Divider(height: 32),

        Text(l.inspectionRecord, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'ok', label: Text(l.inspectionResultOk)),
            ButtonSegment(value: 'defect', label: Text(l.inspectionResultDefect)),
          ],
          selected: {_result},
          onSelectionChanged: _busy ? null : (s) => setState(() => _result = s.first),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          maxLength: 300,
          decoration: InputDecoration(labelText: l.inspectionNote, counterText: ''),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _record,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(l.inspectionRecord),
        ),
        const Divider(height: 32),

        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _intervalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.inspectionSetInterval),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _busy ? null : _saveInterval,
              child: Text(l.inspectionSave),
            ),
          ],
        ),
        const Divider(height: 32),

        if (card.openDefects.isNotEmpty) ...[
          Text(l.inspectionOpenDefects, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final defect in card.openDefects)
            ListTile(
              dense: true,
              leading: const Icon(Icons.report_problem_outlined),
              title: Text(defect.title),
            ),
          const Divider(height: 32),
        ],

        Text(l.inspectionHistory, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (card.inspections.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l.inspectionNever),
          )
        else
          for (final inspection in card.inspections)
            ListTile(
              dense: true,
              leading: Icon(
                inspection.isDefect ? Icons.warning_amber_outlined : Icons.check,
                color: inspection.isDefect
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              title: Text(inspection.isDefect ? l.inspectionResultDefect : l.inspectionResultOk),
              subtitle: Text([
                inspection.by,
                _formatDate(inspection.at, l),
                if (inspection.note.isNotEmpty) inspection.note,
              ].where((e) => e.isNotEmpty).join(' · ')),
            ),
      ],
    );
  }
}
