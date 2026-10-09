import 'package:flutter/material.dart';

class HandoverChip extends StatelessWidget {
  const HandoverChip({super.key, required this.label, required this.colors});

  final String label;
  final ({Color background, Color foreground}) colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.foreground,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

({Color background, Color foreground}) handoverStatusColors(
  BuildContext context,
  Object? status,
) {
  final colors = Theme.of(context).colorScheme;
  return switch (status?.toString()) {
    'open' => (
      background: colors.primaryContainer,
      foreground: colors.onPrimaryContainer,
    ),
    'in_progress' => (
      background: colors.secondaryContainer,
      foreground: colors.onSecondaryContainer,
    ),
    'done' => (
      background: colors.surfaceContainerHighest,
      foreground: colors.onSurface,
    ),
    _ => (
      background: colors.surfaceContainerHigh,
      foreground: colors.onSurface,
    ),
  };
}

({Color background, Color foreground}) handoverPriorityColors(
  BuildContext context,
  Object? priority,
) {
  final colors = Theme.of(context).colorScheme;
  return switch (priority?.toString()) {
    'urgent' => (
      background: colors.errorContainer,
      foreground: colors.onErrorContainer,
    ),
    'important' => (
      background: colors.tertiaryContainer,
      foreground: colors.onTertiaryContainer,
    ),
    _ => (
      background: colors.surfaceContainerHighest,
      foreground: colors.onSurface,
    ),
  };
}

String formatHandoverTimestamp(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (parsed == null) {
    return value?.toString() ?? '—';
  }
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(parsed.day)}.${two(parsed.month)}.${parsed.year}, '
      '${two(parsed.hour)}:${two(parsed.minute)} Uhr';
}
