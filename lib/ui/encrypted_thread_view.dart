import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/crypto/e2ee.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/chat.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';

/// Loaded thread payload: messages plus the recipients a new message must be
/// encrypted for.
class EncryptedThread {
  const EncryptedThread({required this.messages, required this.recipients});
  final List<ChatFeedItem> messages;
  final List<ChatMemberKey> recipients;
}

class _DisplayMessage {
  const _DisplayMessage(this.authorName, this.isOwn, this.text, this.readable);
  final String authorName;
  final bool isOwn;
  final String text;
  final bool readable;
}

/// Reusable message thread: loads ciphertext, decrypts locally with
/// [privateJwk], renders bubbles and encrypts outgoing messages for the
/// current recipients. Used by private 1:1 chats.
class EncryptedThreadView extends StatefulWidget {
  const EncryptedThreadView({
    super.key,
    required this.load,
    required this.send,
    required this.privateJwk,
  });

  final Future<EncryptedThread> Function() load;
  final Future<void> Function(Map<String, dynamic> payload) send;
  final Map<String, dynamic> privateJwk;

  @override
  State<EncryptedThreadView> createState() => _EncryptedThreadViewState();
}

class _EncryptedThreadViewState extends State<EncryptedThreadView> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<_DisplayMessage> _messages = const [];
  List<ChatMemberKey> _recipients = const [];
  final _composeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _composeController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final thread = await widget.load();
      _recipients = thread.recipients;
      _messages = thread.messages.map((item) {
        if (!item.readable) return _DisplayMessage(item.authorName, item.isOwn, '', false);
        try {
          return _DisplayMessage(
            item.authorName,
            item.isOwn,
            E2ee.decryptEnvelope(item.toEnvelope(), widget.privateJwk),
            true,
          );
        } on Object {
          return _DisplayMessage(item.authorName, item.isOwn, '', false);
        }
      }).toList(growable: false);
      if (mounted) setState(() => _loading = false);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _composeController.text.trim();
    if (text.isEmpty) return;
    final recipients = _recipients
        .where((key) => key.hasKeys && key.publicJwk != null)
        .map((key) => key.toRecipient())
        .toList(growable: false);
    if (recipients.isEmpty) return;
    setState(() => _busy = true);
    try {
      final payload = E2ee.encryptForRecipients(text, recipients);
      await widget.send(payload);
      _composeController.clear();
      await _reload();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        if (_error != null)
          Padding(padding: const EdgeInsets.all(12), child: ErrorBanner(message: _error!)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: _messages.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 64),
                        child: Center(child: Text(l.chatEmpty)),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final scheme = Theme.of(context).colorScheme;
                      return Align(
                        alignment:
                            message.isOwn ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: message.isOwn
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.isOwn ? l.chatMe : message.authorName,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(height: 2),
                              message.readable
                                  ? Text(message.text)
                                  : Text(
                                      l.chatUnreadable,
                                      style: const TextStyle(fontStyle: FontStyle.italic),
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _composeController,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: l.chatComposeHint,
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send),
                  tooltip: l.chatSend,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
