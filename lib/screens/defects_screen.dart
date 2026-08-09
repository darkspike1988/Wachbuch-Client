import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/state/defect_state.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/layout.dart';
import 'package:wachbuch_mobile/ui/priority_badge.dart';
import 'package:wachbuch_mobile/ui/status_chip.dart';

/// Mängel list + status updates (demo / future API).
class DefectsScreen extends StatefulWidget {
  const DefectsScreen({super.key, required this.api});

  final WachbuchApi api;

  @override
  State<DefectsScreen> createState() => _DefectsScreenState();
}

class _DefectsScreenState extends State<DefectsScreen> {
  late final DefectState _state;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _state = DefectState(api: widget.api)..reload();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  List<Defect> get _visible {
    final items = _state.items;
    final filter = _statusFilter;
    if (filter == null) return items;
    return items.where((item) => item.status == filter).toList(growable: false);
  }

  Future<void> _openDetail(Defect defect) async {
    final l = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  defect.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PriorityBadge(priority: defect.priority),
                    StatusChip(status: defect.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(defect.description.isEmpty ? l.detailsNoFurtherInfo : defect.description),
                const SizedBox(height: 8),
                Text('${l.defectAssetLabel}: ${defect.assetRef.isEmpty ? "—" : defect.assetRef}'),
                Text('${l.defectOwnerLabel}: ${defect.owner.isEmpty ? "—" : defect.owner}'),
                if (defect.dueDisplay.isNotEmpty)
                  Text('${l.defectDueLabel}: ${defect.dueDisplay}'),
                const SizedBox(height: 16),
                Text(
                  l.defectSetStatus,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final status in const [
                      'open',
                      'in_progress',
                      'waiting',
                      'done',
                    ])
                      FilterChip(
                        label: Text(_statusLabel(l, status)),
                        selected: defect.status == status,
                        onSelected: (_) async {
                          final ok = await _state.setStatus(defect.id, status);
                          if (context.mounted) Navigator.of(context).pop();
                          if (!ok && mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(_state.error ?? l.detailsLoadFailed),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(AppLocalizations l, String status) {
    return switch (status) {
      'in_progress' => l.handoverStatusInProgress,
      'waiting' => l.defectStatusWaiting,
      'done' => l.handoverStatusDone,
      _ => l.handoverStatusOpen,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final maxW = AppLayout.contentMaxWidth(width);

    return Scaffold(
      appBar: AppBar(title: Text(l.defectsTitle)),
      body: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          final items = _visible;
          return RefreshIndicator(
            onRefresh: _state.reload,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      l.defectsHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final status in const [
                          'open',
                          'in_progress',
                          'waiting',
                          'done',
                        ])
                          FilterChip(
                            label: Text(_statusLabel(l, status)),
                            selected: _statusFilter == status,
                            onSelected: (selected) {
                              setState(() {
                                _statusFilter = selected ? status : null;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_state.error != null) ...[
                      ErrorBanner(message: _state.error!),
                      const SizedBox(height: 12),
                    ],
                    if (_state.loading && !_state.hasData)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l.defectsEmpty),
                      )
                    else
                      ...items.map(
                        (defect) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DefectCard(
                            defect: defect,
                            onTap: () => _openDetail(defect),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DefectCard extends StatelessWidget {
  const _DefectCard({required this.defect, required this.onTap});

  final Defect defect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: WachbuchTokens.touchTarget),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PriorityBadge(priority: defect.priority),
                    StatusChip(status: defect.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  defect.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (defect.assetRef.isNotEmpty) defect.assetRef,
                    if (defect.owner.isNotEmpty) defect.owner,
                    if (defect.dueDisplay.isNotEmpty)
                      '${l.defectDueLabel}: ${defect.dueDisplay}',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
