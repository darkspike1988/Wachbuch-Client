import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/report_stats.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/layout.dart';

/// Client-side Auswertung over defects, assets and checklists (Phase 4).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.api});

  final WachbuchApi api;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportStats? _stats;
  bool _loading = true;
  String? _error;

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
      final defects = await _loadDefects();
      final assets = await _loadAssets();
      final checklists = await _loadChecklists();
      if (!mounted) return;
      setState(() {
        _stats = ReportStats.from(
          defects: defects,
          assets: assets,
          checklists: checklists,
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<List<Defect>> _loadDefects() async {
    try {
      return await widget.api.defects();
    } on ApiException catch (error) {
      if (WachbuchApi.isModuleUnavailable(error)) return const [];
      rethrow;
    }
  }

  Future<List<StationAsset>> _loadAssets() async {
    try {
      return await widget.api.assets();
    } on ApiException catch (error) {
      if (WachbuchApi.isModuleUnavailable(error)) return const [];
      rethrow;
    }
  }

  Future<List<Checklist>> _loadChecklists() async {
    try {
      return await widget.api.checklisten();
    } on ApiException catch (error) {
      if (WachbuchApi.isModuleUnavailable(error)) return const [];
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final maxW = AppLayout.contentMaxWidth(width);
    final stats = _stats;

    return Scaffold(
      appBar: AppBar(title: Text(l.reportsTitle)),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l.reportsHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  const SizedBox(height: 12),
                ],
                if (_loading && stats == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (stats != null) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 600 ? 3 : 1;
                      final cardWidth =
                          (constraints.maxWidth - (8 * (columns - 1))) /
                              columns;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetricCard(
                            width: cardWidth,
                            value: '${stats.openDefects.length}',
                            label: l.reportsOpenDefects,
                            urgent: stats.openDefects.isNotEmpty,
                          ),
                          _MetricCard(
                            width: cardWidth,
                            value: '${stats.overdueChecks}',
                            label: l.reportsOverdueChecks,
                            urgent: stats.overdueChecks > 0,
                          ),
                          _MetricCard(
                            width: cardWidth,
                            value: '${stats.ampQuotePercent}%',
                            label: l.reportsAmpQuote,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l.reportsByOwnerTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (stats.byOwner.isEmpty)
                    Text(
                      l.reportsNoOpenDefects,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    )
                  else
                    ...stats.byOwner.entries.map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: Text('${entry.value}'),
                        ),
                        title: Text(entry.key),
                        subtitle: Text(l.reportsOwnerCount(entry.value)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    l.reportsAssetsTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.reportsAssetsReady(
                      stats.readyAssets,
                      stats.totalAssets,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.value,
    required this.label,
    this.urgent = false,
  });

  final double width;
  final String value;
  final String label;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = urgent ? WachbuchTokens.urgent : scheme.primary;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
