import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/services/offline_read_cache.dart';
import 'package:wachbuch_mobile/state/defect_state.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/layout.dart';
import 'package:wachbuch_mobile/ui/priority_badge.dart';
import 'package:wachbuch_mobile/ui/status_chip.dart';

/// Mängel list + create + status updates + demo attachments.
class DefectsScreen extends StatefulWidget {
  const DefectsScreen({super.key, required this.api, this.cache});

  final WachbuchApi api;
  final OfflineReadCache? cache;

  @override
  State<DefectsScreen> createState() => _DefectsScreenState();
}

class _DefectsScreenState extends State<DefectsScreen> {
  late final DefectState _state;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _state = DefectState(api: widget.api, cache: widget.cache)..reload();
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

  Future<void> _createDefect() async {
    final l = AppLocalizations.of(context)!;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final assetController = TextEditingController();
    var priority = 'normal';
    final created = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.defectCreateTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('defect-create-title'),
                    controller: titleController,
                    decoration: InputDecoration(labelText: l.defectCreateTitleField),
                    textInputAction: TextInputAction.next,
                    autofocus: true,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    decoration:
                        InputDecoration(labelText: l.defectCreateDescriptionField),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: assetController,
                    decoration:
                        InputDecoration(labelText: l.defectAssetLabel),
                  ),
                  const SizedBox(height: 12),
                  Text(l.defectCreatePriority, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final value in const ['urgent', 'important', 'normal'])
                        ChoiceChip(
                          label: Text(_priorityLabel(l, value)),
                          selected: priority == value,
                          onSelected: (_) => setModalState(() => priority = value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('defect-create-submit'),
                    onPressed: () {
                      if (titleController.text.trim().isEmpty) return;
                      Navigator.of(context).pop(true);
                    },
                    child: Text(l.defectCreateSubmit),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final assetRef = assetController.text.trim();
    titleController.dispose();
    descriptionController.dispose();
    assetController.dispose();
    if (created != true || title.isEmpty) return;
    final ok = await _state.create({
      'title': title,
      'description': description,
      'asset_ref': assetRef,
      'priority': priority,
      'status': 'open',
      'category': 'task',
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l.defectCreateSuccess : (_state.error ?? l.detailsLoadFailed)),
      ),
    );
  }

  Future<void> _openDetail(Defect defect) async {
    final l = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return ListenableBuilder(
          listenable: _state,
          builder: (context, _) {
            final current = _state.items.firstWhere(
              (item) => item.id == defect.id,
              orElse: () => defect,
            );
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      current.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PriorityBadge(priority: current.priority),
                        StatusChip(status: current.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      current.description.isEmpty
                          ? l.detailsNoFurtherInfo
                          : current.description,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${l.defectAssetLabel}: ${current.assetRef.isEmpty ? "—" : current.assetRef}',
                    ),
                    Text(
                      '${l.defectOwnerLabel}: ${current.owner.isEmpty ? "—" : current.owner}',
                    ),
                    if (current.dueDisplay.isNotEmpty)
                      Text('${l.defectDueLabel}: ${current.dueDisplay}'),
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
                            selected: current.status == status,
                            onSelected: (_) async {
                              final ok =
                                  await _state.setStatus(current.id, status);
                              if (context.mounted) Navigator.of(context).pop();
                              if (!ok && mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _state.error ?? l.detailsLoadFailed,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l.defectAttachmentsTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.defectAttachmentsHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (current.attachments.isEmpty)
                      Text(
                        l.defectAttachmentsEmpty,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      )
                    else
                      ...current.attachments.map(
                        (file) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.attach_file),
                          title: Text(file.name),
                          subtitle: Text(
                            file.localOnly
                                ? l.defectAttachmentLocal
                                : file.contentType,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('defect-add-attachment'),
                      onPressed: () async {
                        final attachment =
                            await _state.addDemoAttachment(current.id);
                        if (!mounted) return;
                        if (attachment == null) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _state.error ?? l.defectAttachmentFailed,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(l.defectAddAttachmentDemo),
                    ),
                  ],
                ),
              ),
            );
          },
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

  String _priorityLabel(AppLocalizations l, String priority) {
    return switch (priority) {
      'urgent' => l.handoverPriorityUrgent,
      'important' => l.handoverPriorityImportant,
      _ => l.handoverPriorityNormal,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final maxW = AppLayout.contentMaxWidth(width);

    return Scaffold(
      appBar: AppBar(title: Text(l.defectsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('defect-create-fab'),
        onPressed: _createDefect,
        icon: const Icon(Icons.add),
        label: Text(l.defectCreateAction),
      ),
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  children: [
                    Text(
                      l.defectsHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    if (_state.fromCache && _state.cacheUpdatedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        l.offlineCacheLabel(
                          _formatCacheTime(_state.cacheUpdatedAt!),
                        ),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                      ),
                    ],
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
                    if (_state.error != null && !_state.fromCache) ...[
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

  String _formatCacheTime(DateTime value) {
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}.${local.month}.${local.year} $hh:$mm';
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
                    if (defect.attachments.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: Text('${defect.attachments.length}'),
                        visualDensity: VisualDensity.compact,
                      ),
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
