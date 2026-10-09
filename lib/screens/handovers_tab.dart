import 'package:wachbuch_mobile/screens/handover_detail_sheet.dart';
import 'package:wachbuch_mobile/ui/handover_presentation.dart';
import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/state/handover_state.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/handover_filter.dart';
import 'package:wachbuch_mobile/ui/layout.dart';

class HandoversTab extends StatefulWidget {
  const HandoversTab({
    super.key,
    required this.api,
    required this.handoverState,
    required this.currentUsername,
    required this.error,
    required this.onRefresh,
  });

  final WachbuchApi api;
  final HandoverState handoverState;
  final String? currentUsername;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  State<HandoversTab> createState() => HandoversTabState();
}

class HandoversTabState extends State<HandoversTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showDetails(Map<String, dynamic> item) async {
    final rawId = item['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null) {
      return;
    }
    final detailFuture = widget.api.handoverDetail(id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => HandoverDetailSheet(
        api: widget.api,
        handoverId: id,
        currentUsername: widget.currentUsername,
        future: detailFuture,
        fallback: item,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.handoverState;
    final items = state.items;
    if (state.loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final cols = AppLayout.handoverColumns(width);
    final maxW = AppLayout.contentMaxWidth(width);
    final filtered = state.filteredItems;
    final availableStatuses = _orderedValues(
      [
        ...items.map((item) => item['status']?.toString() ?? ''),
        ...state.statuses,
      ],
      const ['open', 'in_progress', 'done'],
    );
    final availablePriorities = _orderedValues(
      [
        ...items.map((item) => item['priority']?.toString() ?? ''),
        ...state.priorities,
      ],
      const ['urgent', 'important', 'normal'],
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Column(
          children: [
            if (items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SearchBar(
                  key: const Key('handover-search'),
                  controller: _searchController,
                  hintText: l.handoverSearchHint,
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        tooltip: l.handoverSearchClear,
                        onPressed: () {
                          _searchController.clear();
                          state.setSearchQuery('');
                        },
                        icon: const Icon(Icons.close),
                      ),
                  ],
                  onChanged: (text) => state.setSearchQuery(text),
                ),
              ),
              _FilterSection(
                title: l.filterStatus,
                values: availableStatuses,
                selected: state.statuses,
                label: (value) => handoverStatusLabel(value, l),
                keyPrefix: 'status-filter',
                onChanged: (value, selected) =>
                    state.toggleStatus(value, selected: selected),
              ),
              _FilterSection(
                title: l.filterPriority,
                values: availablePriorities,
                selected: state.priorities,
                label: (value) => handoverPriorityLabel(value, l),
                keyPrefix: 'priority-filter',
                onChanged: (value, selected) =>
                    state.togglePriority(value, selected: selected),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.handoversCount(filtered.length, items.length),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
            ],
            Expanded(
              child: RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: _HandoverResults(
                  items: filtered,
                  allItemsEmpty: items.isEmpty,
                  error: widget.error,
                  columns: cols,
                  onOpen: _showDetails,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    required this.keyPrefix,
    required this.onChanged,
  });

  final String title;
  final List<String> values;
  final Set<String> selected;
  final String Function(Object?) label;
  final String keyPrefix;
  final void Function(String value, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 2),
      child: Semantics(
        container: true,
        label: l.filterSectionLabel(title),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  for (final value in values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        key: Key('$keyPrefix-$value'),
                        label: Text(label(value)),
                        selected: selected.contains(value),
                        showCheckmark: true,
                        onSelected: (active) => onChanged(value, active),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HandoverResults extends StatelessWidget {
  const _HandoverResults({
    required this.items,
    required this.allItemsEmpty,
    required this.error,
    required this.columns,
    required this.onOpen,
  });

  final List<Map<String, dynamic>> items;
  final bool allItemsEmpty;
  final String? error;
  final int columns;
  final void Function(Map<String, dynamic> item) onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (error != null && allItemsEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [ErrorBanner(message: error!)],
      );
    }
    if (allItemsEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [Text(l.handoversNoneActive)],
      );
    }
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [Text(l.handoversNoneForFilter)],
      );
    }
    if (columns == 1) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) =>
            _HandoverCard(item: items[index], onOpen: onOpen),
      );
    }
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: _handoverCardExtent(context),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _HandoverCard(item: items[index], onOpen: onOpen),
    );
  }
}

class _HandoverCard extends StatelessWidget {
  const _HandoverCard({required this.item, required this.onOpen});

  final Map<String, dynamic> item;
  final void Function(Map<String, dynamic> item) onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final title = item['title']?.toString().trim();
    return Semantics(
      button: true,
      label: l.handoverOpenSemantics(
        title?.isNotEmpty == true ? title! : l.handoverUntitled,
      ),
      child: SizedBox(
        height: _handoverCardExtent(context),
        child: Card(
          margin: const EdgeInsets.all(4),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onOpen(item),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  color: handoverPriorityColors(
                    context,
                    item['priority'],
                  ).foreground,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title?.isNotEmpty == true
                              ? title!
                              : l.handoverFallback,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          handoverCategoryLabel(item['category'], l),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const Spacer(),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            HandoverChip(
                              label: handoverStatusLabel(item['status'], l),
                              colors: handoverStatusColors(
                                context,
                                item['status'],
                              ),
                            ),
                            HandoverChip(
                              label: handoverPriorityLabel(item['priority'], l),
                              colors: handoverPriorityColors(
                                context,
                                item['priority'],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

List<String> _orderedValues(Iterable<String> values, List<String> order) {
  final available = values.where((value) => value.isNotEmpty).toSet();
  final result = order.where(available.remove).toList();
  final unknown = available.toList()..sort();
  return [...result, ...unknown];
}

double _handoverCardExtent(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  final extraScale = (scale - 1).clamp(0.0, 2.0);
  return 196 + (190 * extraScale);
}
