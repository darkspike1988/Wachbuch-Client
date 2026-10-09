import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';
import 'package:wachbuch_mobile/screens/assets_screen.dart';
import 'package:wachbuch_mobile/screens/chat_screen.dart';
import 'package:wachbuch_mobile/screens/checklisten_screen.dart';
import 'package:wachbuch_mobile/screens/defects_screen.dart';
import 'package:wachbuch_mobile/screens/groups_screen.dart';
import 'package:wachbuch_mobile/screens/kaffeekasse_screen.dart';
import 'package:wachbuch_mobile/screens/kalender_screen.dart';
import 'package:wachbuch_mobile/screens/pinnwand_screen.dart';
import 'package:wachbuch_mobile/screens/reports_screen.dart';
import 'package:wachbuch_mobile/ui/asset_status_board.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/layout.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({
    super.key,
    required this.api,
    required this.stationName,
    required this.roleLabel,
    required this.modules,
    required this.handovers,
    required this.loading,
    required this.hasData,
    required this.error,
    required this.onRefresh,
  });

  final WachbuchApi api;
  final String stationName;
  final String roleLabel;
  final Map<String, dynamic> modules;
  final List<Map<String, dynamic>> handovers;
  final bool loading;
  final bool hasData;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading && !hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    final l = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final width = MediaQuery.sizeOf(context).width;
    final maxW = AppLayout.contentMaxWidth(width);
    final openCount = handovers
        .where((item) => item['status'] == 'open')
        .length;
    final inProgressCount = handovers
        .where((item) => item['status'] == 'in_progress')
        .length;
    final urgentCount = handovers
        .where((item) => item['priority'] == 'urgent')
        .length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StationHero(stationName: stationName, roleLabel: roleLabel),
              const SizedBox(height: 16),
              if (error != null) ...[
                ErrorBanner(message: error!),
                const SizedBox(height: 16),
              ],
              _SectionTitle(
                icon: Icons.monitor_heart_outlined,
                title: l.overviewActiveHandovers,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(14) / 14;
                  final columns = constraints.maxWidth < 360 || textScale > 1.3
                      ? 2
                      : 3;
                  final metricWidth =
                      (constraints.maxWidth - (8 * (columns - 1))) / columns;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DashboardMetric(
                        key: const Key('overview-stat-open'),
                        width: metricWidth,
                        icon: Icons.inbox_outlined,
                        value: openCount,
                        label: l.metricOpen,
                      ),
                      _DashboardMetric(
                        key: const Key('overview-stat-progress'),
                        width: metricWidth,
                        icon: Icons.pending_actions_outlined,
                        value: inProgressCount,
                        label: l.metricInProgress,
                      ),
                      _DashboardMetric(
                        key: const Key('overview-stat-urgent'),
                        width: metricWidth,
                        icon: Icons.priority_high_rounded,
                        value: urgentCount,
                        label: l.metricUrgent,
                        urgent: urgentCount > 0,
                      ),
                    ],
                  );
                },
              ),
              if (modules['assets'] == true) ...[
                const SizedBox(height: 24),
                _OverviewAssetBoard(api: api),
              ],
              const SizedBox(height: 24),
              _SectionTitle(
                icon: Icons.dashboard_customize_outlined,
                title: l.overviewModulesTitle,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: modules.entries.map((entry) {
                  final on = entry.value == true;
                  return Chip(
                    avatar: Icon(
                      on ? Icons.check_circle : Icons.remove_circle_outline,
                      size: 18,
                    ),
                    label: Text(
                      moduleLabel(entry.key, languageCode: languageCode),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              _ModuleTiles(api: api, modules: modules),
              const SizedBox(height: 24),
              Material(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.overviewModulesHint,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationHero extends StatelessWidget {
  const _StationHero({required this.stationName, required this.roleLabel});

  final String stationName;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: scheme.onPrimary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.local_hospital_outlined,
                color: scheme.onPrimary,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stationName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: scheme.onPrimary),
                  ),
                  if (roleLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      roleLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 24, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    super.key,
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
    this.urgent = false,
  });

  final double width;
  final IconData icon;
  final int value;
  final String label;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = urgent ? scheme.errorContainer : scheme.surface;
    final foreground = urgent ? scheme.onErrorContainer : scheme.onSurface;
    final accent = urgent ? scheme.error : scheme.primary;
    return SizedBox(
      width: width,
      child: Card(
        color: background,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: accent),
              const SizedBox(height: 10),
              Text(
                '$value $label',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleTiles extends StatelessWidget {
  const _ModuleTiles({required this.api, required this.modules});

  final WachbuchApi api;
  final Map<String, dynamic> modules;

  /// Module key -> list of tiles to render when the module is enabled.
  /// `chat` renders two tiles (chat + groups); `assets` also matches `inventory`.
  static const _moduleTiles = <_ModuleTileSpec>[
    _ModuleTileSpec(['calendar'], 'module-tile-calendar', Icons.event_outlined),
    _ModuleTileSpec(['coffee'], 'module-tile-coffee', Icons.coffee_outlined),
    _ModuleTileSpec(
      ['checklists'],
      'module-tile-checklists',
      Icons.checklist_outlined,
    ),
    _ModuleTileSpec(
      ['defects'],
      'module-tile-defects',
      Icons.report_problem_outlined,
    ),
    _ModuleTileSpec(
      ['assets', 'inventory'],
      'module-tile-assets',
      Icons.directions_car_outlined,
    ),
    _ModuleTileSpec(
      ['reports'],
      'module-tile-reports',
      Icons.insights_outlined,
    ),
    _ModuleTileSpec(['chat'], 'module-tile-chat', Icons.forum_outlined),
    _ModuleTileSpec(['chat'], 'module-tile-groups', Icons.groups_outlined),
    _ModuleTileSpec(
      ['pinboard'],
      'module-tile-pinboard',
      Icons.push_pin_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final destinations = [
      for (final spec in _moduleTiles)
        if (spec.keys.any((key) => modules[key] == true))
          _ModuleDestination(
            key: spec.tileKey,
            icon: spec.icon,
            title: _tileTitle(spec.tileKey, l),
            subtitle: _tileSubtitle(spec.tileKey, l),
          ),
    ];
    if (destinations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.apps_outlined, title: l.quickAccessTitle),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 600 ? 3 : 2;
            final tileWidth =
                (constraints.maxWidth - (8 * (columns - 1))) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final destination in destinations)
                  _ModuleTile(
                    key: Key(destination.key),
                    width: tileWidth,
                    destination: destination,
                    onTap: () => _open(context, destination),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _tileTitle(String key, AppLocalizations l) {
    return switch (key) {
      'module-tile-calendar' => l.moduleCalendarTitle,
      'module-tile-coffee' => l.moduleCoffeeTitle,
      'module-tile-checklists' => l.moduleChecklistsTitle,
      'module-tile-defects' => l.moduleDefectsTitle,
      'module-tile-assets' => l.moduleAssetsTitle,
      'module-tile-reports' => l.moduleReportsTitle,
      'module-tile-chat' => l.chatTitle,
      'module-tile-groups' => l.groupsTitle,
      'module-tile-pinboard' => l.pinboardTitle,
      _ => key,
    };
  }

  static String _tileSubtitle(String key, AppLocalizations l) {
    return switch (key) {
      'module-tile-calendar' => l.moduleCalendarSubtitle,
      'module-tile-coffee' => l.moduleCoffeeSubtitle,
      'module-tile-checklists' => l.moduleChecklistsSubtitle,
      'module-tile-defects' => l.moduleDefectsSubtitle,
      'module-tile-assets' => l.moduleAssetsSubtitle,
      'module-tile-reports' => l.moduleReportsSubtitle,
      'module-tile-chat' => l.chatSubtitle,
      'module-tile-groups' => l.groupsSubtitle,
      'module-tile-pinboard' => l.pinboardSubtitle,
      _ => '',
    };
  }

  void _open(BuildContext context, _ModuleDestination destination) {
    final Widget screen;
    switch (destination.key) {
      case 'module-tile-calendar':
        screen = KalenderScreen(api: api);
      case 'module-tile-coffee':
        screen = KaffeekasseScreen(api: api);
      case 'module-tile-checklists':
        screen = ChecklistenScreen(api: api);
      case 'module-tile-defects':
        screen = DefectsScreen(api: api);
      case 'module-tile-assets':
        screen = AssetsScreen(api: api);
      case 'module-tile-reports':
        screen = ReportsScreen(api: api);
      case 'module-tile-chat':
        screen = ChatScreen(api: api);
      case 'module-tile-groups':
        screen = GroupsScreen(api: api);
      case 'module-tile-pinboard':
        screen = PinnwandScreen(api: api);
      default:
        return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

/// Loads station assets for the overview board; hides on 501 / empty.
class _OverviewAssetBoard extends StatefulWidget {
  const _OverviewAssetBoard({required this.api});

  final WachbuchApi api;

  @override
  State<_OverviewAssetBoard> createState() => _OverviewAssetBoardState();
}

class _OverviewAssetBoardState extends State<_OverviewAssetBoard> {
  List<StationAsset> _assets = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _OverviewAssetBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<StationAsset> assets = const [];
    try {
      assets = await widget.api.assets();
    } catch (_) {
      // Module optional: hide on any error instead of breaking the overview.
    }
    if (!mounted) return;
    setState(() {
      _assets = assets;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _assets.isEmpty) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return AssetStatusBoard(assets: _assets);
  }
}

class _ModuleTileSpec {
  const _ModuleTileSpec(this.keys, this.tileKey, this.icon);

  final List<String> keys;
  final String tileKey;
  final IconData icon;
}

class _ModuleDestination {
  const _ModuleDestination({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String key;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    super.key,
    required this.width,
    required this.destination,
    required this.onTap,
  });

  final double width;
  final _ModuleDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(destination.icon, size: 28, color: scheme.primary),
                const SizedBox(height: 10),
                Text(
                  destination.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  destination.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
