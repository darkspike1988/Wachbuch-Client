import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/ui/layout.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({
    super.key,
    required this.me,
    required this.serverUrl,
    required this.loading,
    required this.onLogout,
    required this.onChangeServer,
    required this.onRefresh,
  });

  final Map<String, dynamic>? me;
  final String serverUrl;
  final bool loading;
  final Future<void> Function() onLogout;
  final Future<void> Function() onChangeServer;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = me?['user'] as Map?;
    final width = MediaQuery.sizeOf(context).width;
    final maxW = AppLayout.contentMaxWidth(width);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.accountLoggedInAs),
              subtitle: Text((user?['username'] as String?) ?? '—'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.accountServer),
              subtitle: Text(serverUrl),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.accountLicense),
              subtitle: Text(l.accountLicenseValue),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: loading ? null : onRefresh,
              child: Text(l.accountRefreshProfile),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: loading ? null : onLogout,
              child: Text(l.accountLogout),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: loading ? null : onChangeServer,
              child: Text(l.accountChangeServer),
            ),
          ],
        ),
      ),
    );
  }
}
