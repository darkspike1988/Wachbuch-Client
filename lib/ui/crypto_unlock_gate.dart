import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/crypto/e2ee.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/state/crypto_session.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';

/// Ensures the E2EE [CryptoSession] is unlocked before showing [builder].
///
/// Reused by the private-chat and secure-mail screens. If no identity exists
/// yet it points the user to the Wachenchat (station chat) where keys are set
/// up. The unlocked private key stays in memory only (see [CryptoSession]).
class CryptoUnlockGate extends StatefulWidget {
  const CryptoUnlockGate({
    super.key,
    required this.api,
    required this.session,
    required this.builder,
  });

  final WachbuchApi api;
  final CryptoSession session;
  final Widget Function(BuildContext context, Map<String, dynamic> privateJwk) builder;

  @override
  State<CryptoUnlockGate> createState() => _CryptoUnlockGateState();
}

class _CryptoUnlockGateState extends State<CryptoUnlockGate> {
  bool _loading = true;
  bool _needsSetup = false;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _bundle;

  final _passphraseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    if (widget.session.isUnlocked) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final identity = await widget.api.chatIdentity();
      if (identity['configured'] != true) {
        setState(() {
          _loading = false;
          _needsSetup = true;
        });
        return;
      }
      setState(() {
        _bundle = identity;
        _loading = false;
      });
    } on ApiException catch (error) {
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _unlock() async {
    final passphrase = _passphraseController.text;
    if (passphrase.isEmpty || _bundle == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final privateJwk = E2ee.unlockIdentity(
        wrappedPrivateJwk: _bundle!['wrapped_private_jwk'] as String,
        kdfSalt: _bundle!['kdf_salt'] as String,
        kdfIterations: (_bundle!['kdf_iterations'] as num).toInt(),
        passphrase: passphrase,
      );
      widget.session.unlockWith(privateJwk);
      _passphraseController.clear();
      setState(() {});
    } on E2eeException {
      setState(() => _error = AppLocalizations.of(context)!.chatWrongPassphrase);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (widget.session.isUnlocked) {
      return widget.builder(context, widget.session.privateJwk!);
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_needsSetup) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.chatSetupTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l.chatMessagingSetupHint),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.chatUnlockTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(l.chatUnlockHint),
        const SizedBox(height: 16),
        if (_error != null) ...[
          ErrorBanner(message: _error!),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _passphraseController,
          obscureText: true,
          decoration: InputDecoration(labelText: l.chatPassphrase),
          onSubmitted: (_) => _unlock(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _unlock,
          child: _busy
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.chatUnlockAction),
        ),
      ],
    );
  }
}
