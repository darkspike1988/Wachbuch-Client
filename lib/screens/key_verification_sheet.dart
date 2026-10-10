import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/crypto/e2ee.dart' as e2ee;
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/chat.dart';

/// Key verification sheet (R-020): colleagues compare E2EE key fingerprints.
///
/// Shows the own fingerprint (long-press to copy) and the station members'
/// fingerprints. "Verify by scan" opens the camera; a scanned string
/// matching a member fingerprint marks that key as verified in this session.
class KeyVerificationSheet extends StatefulWidget {
  const KeyVerificationSheet({super.key, required this.api});

  final WachbuchApi api;

  @override
  State<KeyVerificationSheet> createState() => _KeyVerificationSheetState();
}

class _KeyVerificationSheetState extends State<KeyVerificationSheet> {
  bool _loading = true;
  String? _error;
  String? _ownFingerprint;
  List<ChatMemberKey> _members = const [];
  final Map<int, String> _verified = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final identity = await widget.api.chatIdentity();
      final members = await widget.api.chatMemberKeys();
      final jwk = identity['public_jwk'];
      if (!mounted) return;
      setState(() {
        _ownFingerprint = identity['fingerprint'] is String &&
                (identity['fingerprint'] as String).isNotEmpty
            ? identity['fingerprint'] as String
            : e2ee.keyFingerprint(
                jwk is Map ? Map<String, dynamic>.from(jwk) : null,
              );
        _members = members;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _verifyByScan() async {
    final l = AppLocalizations.of(context)!;
    final scanned = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l.keyVerifyScanTitle),
            ),
            SizedBox(
              height: 260,
              width: 300,
              child: MobileScanner(
                onDetect: (capture) {
                  final value = capture.barcodes.firstOrNull?.rawValue;
                  if (value != null && value.isNotEmpty) {
                    Navigator.pop(ctx, value);
                  }
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.commonCancel),
            ),
          ],
        ),
      ),
    );
    if (scanned == null || scanned.isEmpty || !mounted) return;
    final normalized = scanned.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final match = _members.where((m) {
      final fp = m.fingerprint;
      return fp != null &&
          fp.replaceAll(RegExp(r'\s+'), '').toLowerCase() == normalized;
    }).toList(growable: false);
    final message = match.isEmpty
        ? l.keyVerifyNoMatch
        : l.keyVerifyMatch(match.first.label);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    if (match.isNotEmpty) {
      setState(() {
        _verified[match.first.userId] = match.first.fingerprint!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.keyVerifyTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: _verifyByScan,
                tooltip: l.keyVerifyScanAction,
                icon: const Icon(Icons.qr_code_scanner),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.keyVerifyExplanation,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error))
          else ...[
            if (_ownFingerprint != null)
              _FingerprintCard(
                label: l.keyVerifyOwnKey,
                fingerprint: _ownFingerprint!,
                own: true,
                verified: true,
              ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final member in _members)
                    if (member.fingerprint != null)
                      _FingerprintCard(
                        label: member.label,
                        fingerprint: member.fingerprint!,
                        own: false,
                        verified: _verified.containsKey(member.userId),
                      ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FingerprintCard extends StatelessWidget {
  const _FingerprintCard({
    required this.label,
    required this.fingerprint,
    required this.own,
    required this.verified,
  });

  final String label;
  final String fingerprint;
  final bool own;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: fingerprint));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.keyVerifyCopied)),
          );
        },
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  verified ? Icons.verified_outlined : Icons.key_outlined,
                  color: verified ? theme.colorScheme.primary : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              style: theme.textTheme.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (own) ...[
                            const SizedBox(width: 6),
                            Text(
                              l.keyVerifyOwnTag,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (verified && !own) ...[
                            const SizedBox(width: 6),
                            Text(
                              l.keyVerifyVerifiedTag,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fingerprint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
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
