import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/chat.dart';
import 'package:wachbuch_mobile/state/crypto_session.dart';
import 'package:wachbuch_mobile/ui/crypto_unlock_gate.dart';
import 'package:wachbuch_mobile/ui/encrypted_thread_view.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/layout.dart';

/// Private 1:1 conversations list with a colleague picker to start new chats.
class PrivateChatScreen extends StatefulWidget {
  PrivateChatScreen({super.key, required this.api, CryptoSession? session})
      : session = session ?? CryptoSession.instance;

  final WachbuchApi api;
  final CryptoSession session;

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  bool _loading = true;
  String? _error;
  List<ChatConversation> _conversations = const [];
  List<ChatMemberKey> _colleagues = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final home = await widget.api.privateConversations();
      if (!mounted) return;
      setState(() {
        _conversations = home.conversations;
        _colleagues = home.colleagues.where((c) => c.hasKeys).toList(growable: false);
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

  void _openThread(int id, String title) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PrivateThreadScreen(
        api: widget.api,
        conversationId: id,
        title: title,
        session: widget.session,
      ),
    ));
  }

  Future<void> _startChat() async {
    final l = AppLocalizations.of(context)!;
    if (_colleagues.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.privateNoColleagues)));
      return;
    }
    final peer = await showModalBottomSheet<ChatMemberKey>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.privatePickColleague,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final colleague in _colleagues)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(colleague.label),
                onTap: () => Navigator.of(context).pop(colleague),
              ),
          ],
        ),
      ),
    );
    if (peer == null) return;
    try {
      final id = await widget.api.startPrivateConversation(peer.userId);
      if (!mounted) return;
      _openThread(id, peer.label);
      await _reload();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(title: Text(l.privateTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startChat,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(l.privateStart),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: AppLayout.contentMaxWidth(width)),
          child: _body(context, l),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l) {
    if (_loading && _conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          if (_conversations.isEmpty && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Center(child: Text(l.privateEmpty)),
            )
          else
            for (final conversation in _conversations)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(conversation.otherName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openThread(conversation.id, conversation.otherName),
                ),
              ),
        ],
      ),
    );
  }
}

/// A single private conversation, gated by the E2EE unlock.
class PrivateThreadScreen extends StatelessWidget {
  PrivateThreadScreen({
    super.key,
    required this.api,
    required this.conversationId,
    required this.title,
    CryptoSession? session,
  }) : session = session ?? CryptoSession.instance;

  final WachbuchApi api;
  final int conversationId;
  final String title;
  final CryptoSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: CryptoUnlockGate(
        api: api,
        session: session,
        builder: (context, privateJwk) => EncryptedThreadView(
          privateJwk: privateJwk,
          load: () async {
            final thread = await api.privateThread(conversationId);
            return EncryptedThread(
              messages: thread.messages,
              recipients: thread.peerKeys,
            );
          },
          send: (payload) => api.sendPrivateMessage(conversationId, payload),
        ),
      ),
    );
  }
}
