import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/services/update_service.dart';

/// Dialog widget for showing update information to users
class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final UpdateService updateService;
  final bool showIgnoreButton;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.updateService,
    this.showIgnoreButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isForced = updateInfo.forceUpdate;

    return AlertDialog(
      title: Row(
        children: [
          if (isForced)
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.error,
              size: 24,
            )
          else
            Icon(
              Icons.system_update_alt,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          const SizedBox(width: 8),
          Text(
            isForced ? 'Wichtiges Update erforderlich' : 'Neue Version verfügbar',
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Version info
            Row(
              children: [
                Text(
                  'Aktuelle Version: ',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  updateInfo.currentVersion,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Neue Version: ',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  updateInfo.latestVersion,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            if (updateInfo.releaseDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Veröffentlicht am: ${_formatDate(updateInfo.releaseDate!)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            
            // Changelog section
            if (updateInfo.changelog.isNotEmpty) ...[
              Text(
                'Was gibt es Neues?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...updateInfo.changelog.map((entry) => _buildChangelogEntry(context, entry)),
            ],
            
            // Force update warning
            if (isForced) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dieses Update ist erforderlich, um die App weiter nutzen zu können.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (showIgnoreButton && !isForced)
          TextButton(
            onPressed: () {
              updateService.ignoreUpdate(updateInfo.latestVersion);
              Navigator.of(context).pop();
            },
            child: const Text('Später erinnern'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
        if (updateInfo.downloadUrl != null && updateInfo.downloadUrl!.isNotEmpty)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              updateService.openDownloadUrl(updateInfo);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: Text(
              isForced ? 'Jetzt updaten' : 'Update herunterladen',
            ),
          ),
      ],
    );
  }

  Widget _buildChangelogEntry(BuildContext context, ChangelogEntry entry) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Version ${entry.version}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          entry.date,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entry.changes.map((change) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Expanded(
                    child: Text(
                      change,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String _formatDate(DateTime date) {
    // Format date in German locale
    return '${date.day}.${date.month}.${date.year}';
  }
}

/// Simple dialog for forced updates that blocks app usage
class ForcedUpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final UpdateService updateService;

  const ForcedUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.updateService,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent closing
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Update erforderlich'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Um die App weiter nutzen zu können, müssen Sie auf die neueste Version updaten.',
              ),
              const SizedBox(height: 16),
              Text(
                'Aktuelle Version: ${updateInfo.currentVersion}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Erforderliche Version: ${updateInfo.latestVersion}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (updateInfo.changelog.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Was gibt es Neues?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...updateInfo.changelog.map((entry) => 
                  _buildChangelogEntry(context, entry)
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              updateService.openDownloadUrl(updateInfo);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('Jetzt updaten'),
          ),
        ],
      ),
    );
  }

  Widget _buildChangelogEntry(BuildContext context, ChangelogEntry entry) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Version ${entry.version}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          entry.date,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entry.changes.map((change) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Expanded(
                    child: Text(
                      change,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
