import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/inventory_item.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';
import 'package:wachbuch_mobile/services/offline_read_cache.dart';
import 'package:wachbuch_mobile/theme/design_tokens.dart';
import 'package:wachbuch_mobile/ui/asset_status_board.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/layout.dart';

/// Vehicle/device statusboard + Schlüssel/Pool checkout (Phase C + G + Welle 2).
class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key, required this.api, this.cache});

  final WachbuchApi api;
  final OfflineReadCache? cache;

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  List<StationAsset> _assets = const [];
  List<InventoryItem> _inventory = const [];
  bool _loading = true;
  bool _fromCache = false;
  DateTime? _cacheUpdatedAt;
  String? _error;
  final Set<String> _busy = {};

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
      final assets = await widget.api.assets();
      List<InventoryItem> inventory = const [];
      try {
        inventory = await widget.api.inventory();
      } on ApiException catch (error) {
        if (!WachbuchApi.isModuleUnavailable(error)) rethrow;
      }
      if (!mounted) return;
      final updatedAt = DateTime.now();
      setState(() {
        _assets = assets;
        _inventory = inventory;
        _loading = false;
        _fromCache = false;
        _cacheUpdatedAt = updatedAt;
      });
      widget.cache?.write(assets: assets, updatedAt: updatedAt);
    } on ApiException catch (error) {
      if (!mounted) return;
      final usedCache = await _tryCache();
      setState(() {
        _error = usedCache ? null : error.message;
        _loading = false;
        if (WachbuchApi.isModuleUnavailable(error) && !usedCache) {
          _assets = const [];
        }
      });
    } catch (error) {
      if (!mounted) return;
      final usedCache = await _tryCache();
      setState(() {
        _error = usedCache ? null : error.toString();
        _loading = false;
      });
    }
  }

  Future<bool> _tryCache() async {
    final snapshot = await widget.cache?.read();
    if (snapshot == null || snapshot.assets.isEmpty) return false;
    setState(() {
      _assets = snapshot.assets;
      _fromCache = true;
      _cacheUpdatedAt = snapshot.updatedAt;
    });
    return true;
  }

  Future<void> _editAssetStatus(StationAsset asset) async {
    final l = AppLocalizations.of(context)!;
    final noteController = TextEditingController(text: asset.note);
    var status = asset.status;
    final apply = await showModalBottomSheet<bool>(
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
                    asset.label,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(l.assetSetStatus),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value in const [
                        'ready',
                        'limited',
                        'workshop',
                        'oob',
                      ])
                        ChoiceChip(
                          label: Text(_assetStatusLabel(l, value)),
                          selected: status == value,
                          onSelected: (_) =>
                              setModalState(() => status = value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(labelText: l.assetNoteLabel),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('asset-status-submit'),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(l.assetStatusSave),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (apply != true) return;
    try {
      final updated = await widget.api.updateAssetStatus(
        asset.id,
        status: status,
        note: note,
      );
      if (!mounted) return;
      setState(() {
        _assets = [
          for (final item in _assets)
            if (item.id == asset.id) updated else item,
        ];
        _fromCache = false;
      });
      await widget.cache?.write(assets: _assets);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _toggleInventory(InventoryItem item) async {
    if (_busy.contains(item.id)) return;
    setState(() => _busy.add(item.id));
    try {
      final updated = item.isOut
          ? await widget.api.inventoryCheckin(item.id)
          : await widget.api.inventoryCheckout(item.id);
      if (!mounted) return;
      setState(() {
        _inventory = [
          for (final entry in _inventory)
            if (entry.id == item.id) updated else entry,
        ];
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  String _assetStatusLabel(AppLocalizations l, String status) {
    return switch (status) {
      'ready' => l.assetStatusReady,
      'limited' => l.assetStatusLimited,
      'workshop' => l.assetStatusWorkshop,
      _ => l.assetStatusOob,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final maxW = AppLayout.contentMaxWidth(width);

    return Scaffold(
      appBar: AppBar(title: Text(l.assetsScreenTitle)),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  const SizedBox(height: 12),
                ],
                if (_fromCache && _cacheUpdatedAt != null) ...[
                  Text(
                    l.offlineCacheLabel(_formatCacheTime(_cacheUpdatedAt!)),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_loading && _assets.isEmpty && _inventory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  AssetStatusBoard(
                    assets: _assets,
                    onAssetTap: _editAssetStatus,
                  ),
                  if (_inventory.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      l.inventoryTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.inventoryHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    for (final item in _inventory)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _InventoryCard(
                          item: item,
                          busy: _busy.contains(item.id),
                          onToggle: () => _toggleInventory(item),
                        ),
                      ),
                  ],
                  if (!_loading && _assets.isEmpty && _inventory.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l.assetsEmpty),
                    ),
                ],
              ],
            ),
          ),
        ),
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

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.item,
    required this.busy,
    required this.onToggle,
  });

  final InventoryItem item;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final subtitle = item.isOut
        ? '${l.inventoryHolderLabel}: ${item.holder}'
            '${item.sinceDisplay.isNotEmpty ? ' · ${item.sinceDisplay}' : ''}'
        : (item.note.isNotEmpty ? item.note : l.inventoryAvailable);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              item.kind == 'key' ? Icons.key_outlined : Icons.devices_other,
              color: item.isOut ? WachbuchTokens.important : scheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: busy ? null : onToggle,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      item.isOut ? l.inventoryCheckin : l.inventoryCheckout,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
