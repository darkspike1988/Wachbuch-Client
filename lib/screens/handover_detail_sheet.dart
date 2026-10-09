import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/demo/demo_api.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/handover_ack.dart';
import 'package:wachbuch_mobile/state/handover_ack_state.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/handover_filter.dart';
import 'package:wachbuch_mobile/ui/handover_presentation.dart';

class HandoverDetailSheet extends StatefulWidget {
  const HandoverDetailSheet({
    super.key,
    required this.api,
    required this.handoverId,
    required this.currentUsername,
    required this.future,
    required this.fallback,
  });

  final WachbuchApi api;
  final int handoverId;
  final String? currentUsername;
  final Future<Map<String, dynamic>> future;
  final Map<String, dynamic> fallback;

  @override
  State<HandoverDetailSheet> createState() => HandoverDetailSheetState();
}

class HandoverDetailSheetState extends State<HandoverDetailSheet> {
  late final HandoverAckState _ackState;
  bool _creatingDefect = false;

  @override
  void initState() {
    super.initState();
    _ackState = HandoverAckState(
      api: widget.api,
      handoverId: widget.handoverId,
    );
    _ackState.addListener(_onAckChanged);
    _ackState.load();
  }

  void _onAckChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ackState.removeListener(_onAckChanged);
    _ackState.dispose();
    super.dispose();
  }

  String? _ackError(AppLocalizations l) => switch (_ackState.failure) {
    HandoverAckFailure.stale => l.handoverAckStale,
    HandoverAckFailure.invalidRevision => l.handoverAckVersionUnknown,
    HandoverAckFailure.api => _ackState.failureMessage,
    HandoverAckFailure.unexpected => l.handoverAckFailed,
    null => null,
  };

  Future<void> _createDefectFromHandover(
    AppLocalizations l,
    Map<String, dynamic> item,
  ) async {
    if (_creatingDefect) return;
    setState(() => _creatingDefect = true);
    final rawTitle = item['title']?.toString().trim() ?? '';
    final title = rawTitle.isNotEmpty ? rawTitle : l.handoverFallback;
    final details = item['details']?.toString().trim() ?? '';
    try {
      await widget.api.createDefect(
        title: title,
        description: details,
        priority: _mapHandoverPriority(item['priority']),
        category: 'task',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l.moduleDefectsTitle}: $title')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.defectCreateFailed)));
    } finally {
      if (mounted) setState(() => _creatingDefect = false);
    }
  }

  String _mapHandoverPriority(Object? value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    return switch (raw) {
      'urgent' || 'high' => 'urgent',
      'important' || 'medium' => 'important',
      _ => 'normal',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(
      child: FutureBuilder<Map<String, dynamic>>(
        future: widget.future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error! as ApiException).message
                : l.detailsLoadFailed;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorBanner(message: message),
            );
          }
          final item = {...widget.fallback, ...?snapshot.data};
          final rawAuthor = item['author'];
          final author = rawAuthor is Map ? rawAuthor : null;
          final authorName = author?['display_name']?.toString();
          final details = item['details']?.toString().trim();
          // Only the detail response proves which revision was actually read.
          final currentVersion = parseHandoverRevision(
            snapshot.data?['version'],
          );
          final me =
              widget.currentUsername ??
              (widget.api is DemoWachbuchApi
                  ? (widget.api as DemoWachbuchApi).profile.username
                  : null);
          // Only an acknowledgement by this user bound to the *current*
          // revision counts as "by you". Older receipts (other revision) and
          // legacy receipts without a revision (version == null) must not.
          final alreadyAcked = _ackState.acknowledgedBy(me, currentVersion);
          final ackError = _ackError(l);
          final versionUnknown = currentVersion == null;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? l.handoverFallback,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    HandoverChip(
                      label: handoverCategoryLabel(item['category'], l),
                      colors: (
                        background: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        foreground: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    HandoverChip(
                      label: handoverStatusLabel(item['status'], l),
                      colors: handoverStatusColors(context, item['status']),
                    ),
                    HandoverChip(
                      label: handoverPriorityLabel(item['priority'], l),
                      colors: handoverPriorityColors(context, item['priority']),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  details?.isNotEmpty == true
                      ? details!
                      : l.detailsNoFurtherInfo,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                if (authorName?.isNotEmpty == true)
                  _DetailRow(icon: Icons.person_outline, value: authorName!),
                if (item['updated_at'] != null)
                  _DetailRow(
                    icon: Icons.update,
                    value: l.detailsUpdatedAt(
                      formatHandoverTimestamp(item['updated_at']),
                    ),
                  ),
                if (currentVersion != null)
                  _DetailRow(
                    icon: Icons.history,
                    value: l.detailsVersion(currentVersion.toString()),
                  ),
                if (_ackState.supported) ...[
                  const SizedBox(height: 16),
                  Text(
                    l.handoverAckListTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_ackState.loading) Text(l.handoverAckLoading),
                  if (_ackState.loadFailed) ...[
                    ErrorBanner(
                      message: _ackState.loadMessage ?? l.handoverAckLoadFailed,
                    ),
                    TextButton.icon(
                      key: const Key('handover-acks-retry'),
                      onPressed: _ackState.loading ? null : _ackState.load,
                      icon: const Icon(Icons.refresh),
                      label: Text(l.commonRetry),
                    ),
                  ],
                  if (_ackState.receipts.isEmpty &&
                      !_ackState.loading &&
                      !_ackState.loadFailed)
                    Text(
                      l.handoverAckEmpty,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (_ackState.receipts.isNotEmpty)
                    ..._ackState.receipts.map(
                      (ack) => _DetailRow(
                        icon: Icons.verified_outlined,
                        value: ack.version == null
                            ? '${ack.by} · ${formatHandoverTimestamp(ack.at.toIso8601String())} · ${l.handoverAckLegacy}'
                            : '${ack.by} · ${l.detailsVersion(ack.version!.toString())} · ${formatHandoverTimestamp(ack.at.toIso8601String())}',
                      ),
                    ),
                  if (versionUnknown) ...[
                    const SizedBox(height: 8),
                    ErrorBanner(message: l.handoverAckVersionUnknown),
                  ],
                  if (ackError != null) ...[
                    const SizedBox(height: 8),
                    ErrorBanner(message: ackError),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('handover-ack'),
                    onPressed:
                        _ackState.acknowledging ||
                            alreadyAcked ||
                            versionUnknown
                        ? null
                        : () => _ackState.acknowledge(currentVersion),
                    icon: _ackState.acknowledging
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.done_all),
                    label: Text(
                      alreadyAcked ? l.handoverAckDone : l.handoverAckButton,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('handover-to-defect'),
                  onPressed: _creatingDefect
                      ? null
                      : () => _createDefectFromHandover(l, item),
                  icon: _creatingDefect
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.report_problem_outlined),
                  label: Text(l.defectAdd),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
