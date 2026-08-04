import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyIconButton extends StatelessWidget {
  const CopyIconButton({
    super.key,
    required this.value,
    this.tooltip = 'Kopieren',
    this.snackbarText = 'Kopiert',
  });

  final String value;
  final String tooltip;
  final String snackbarText;

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    return IconButton(
      key: const Key('copy-button'),
      tooltip: tooltip,
      icon: const Icon(Icons.copy_outlined),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: value));
        messenger?.showSnackBar(
          SnackBar(
            content: Text(snackbarText),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}
