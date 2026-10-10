import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/crypto/e2ee.dart' as e2ee;
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/chat.dart';
import 'package:wachbuch_mobile/state/verified_keys_store.dart';

/// Key verification sheet (R-020): colleagues compare E2EE key fingerprints.
///
/// Shows the own fingerprint as QR code (long-press to copy) and the station
/// members' fingerprints. Verified fingerprints are persisted per server
/// (VerifiedKeysStore); a changed fingerprint of a previously verified
/// colleague triggers a key-change warning. "Verify by scan" opens the
/// camera and matches a scanned fingerprint against the member list.
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
  final VerifiedKeysStore _store = VerifiedKeysStore();
  final Map<int, String> _verified = {};
  final Map<int, String> _changed = {};
  bool _showOwnQr = false;

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
      final own = identity['fingerprint'] is String &&
              (identity['fingerprint'] as String).isNotEmpty
          ? identity['fingerprint'] as String
          : e2ee.keyFingerprint(
              jwk is Map ? Map<String, dynamic>.from(jwk) : null,
            );
      final stored = await _store.allFor(widget.api.baseUrl);
      if (!mounted) return;
      final verified = <int, String>{};
      final changed = <int, String>{};
      for (final member in members) {
        final fp = member.fingerprint;
        if (fp == null) continue;
        final previous = stored[member.userId.toString()];
        if (previous != null) {
          if (previous == fp) {
            verified[member.userId] = fp;
          } else {
            changed[member.userId] = fp;
          }
        }
      }
      setState(() {
        _ownFingerprint = own;
        _members = members;
        _verified.addAll(verified);
        _changed.addAll(changed);
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
      await _confirmVerified(match.first);
    }
  }

  Future<void> _confirmVerified(ChatMemberKey member) async {
    final changed = await _store.markVerified(
      widget.api.baseUrl,
      member.userId,
      member.fingerprint!,
    );
    if (!mounted) return;
    setState(() {
      _verified[member.userId] = member.fingerprint!;
      _changed.remove(member.userId);
    });
    final l = AppLocalizations.of(context)!;
    if (changed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.keyVerifyReverified(member.label))),
      );
    }
  }

  Future<void> _revoke(ChatMemberKey member) async {
    await _store.remove(widget.api.baseUrl, member.userId);
    if (!mounted) return;
    setState(() => _verified.remove(member.userId));
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
            if (_changed.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.keyVerifyChangedWarning(_changed.length),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_ownFingerprint != null)
              _FingerprintCard(
                label: l.keyVerifyOwnKey,
                fingerprint: _ownFingerprint!,
                own: true,
                verified: true,
                onToggleQr: () =>
                    setState(() => _showOwnQr = !_showOwnQr),
              ),
            if (_showOwnQr && _ownFingerprint != null)
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 8),
                  child: QrImageView(
                    data: _ownFingerprint!,
                    version: QrVersions.auto,
                    size: 180,
                  ),
                ),
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
                        changed: _changed.containsKey(member.userId),
                        onVerify: () => _confirmVerified(member),
                        onRevoke: () => _revoke(member),
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
    this.changed = false,
    this.onToggleQr,
    this.onVerify,
    this.onRevoke,
  });

  final String label;
  final String fingerprint;
  final bool own;
  final bool verified;
  final bool changed;
  final VoidCallback? onToggleQr;
  final VoidCallback? onVerify;
  final VoidCallback? onRevoke;

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
                  verified
                      ? Icons.verified_outlined
                      : changed
                          ? Icons.warning_amber_rounded
                          : Icons.key_outlined,
                  color: verified
                      ? theme.colorScheme.primary
                      : changed
                          ? theme.colorScheme.error
                          : null,
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
                          if (changed && !own) ...[
                            const SizedBox(width: 6),
                            Text(
                              l.keyVerifyChangedTag,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
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
                      if (!own) ...[
                        const SizedBox(height: 4),
                        if (verified)
                          TextButton(
                            onPressed: onRevoke,
                            child: Text(l.keyVerifyRevoke),
                          )
                        else
                          TextButton(
                            onPressed: onVerify,
                            child: Text(l.keyVerifyConfirmAction),
                          ),
                      ],
                    ],
                  ),
                ),
                if (own)
                  IconButton(
                    onPressed: onToggleQr,
                    tooltip: l.keyVerifyShowQr,
                    icon: const Icon(Icons.qr_code_2_outlined),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
