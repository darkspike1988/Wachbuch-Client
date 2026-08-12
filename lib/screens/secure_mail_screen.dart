import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/crypto/e2ee.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/models/chat.dart';
import 'package:wachbuch_mobile/state/crypto_session.dart';
import 'package:wachbuch_mobile/ui/crypto_unlock_gate.dart';
import 'package:wachbuch_mobile/ui/error_banner.dart';
import 'package:wachbuch_mobile/ui/layout.dart';

/// Secure Mail: encrypted internal messages. Bodies are the same
/// JSON `{subject, body}` envelope payload as the web client, so messages are
/// interoperable across web and mobile.
class SecureMailScreen extends StatefulWidget {
  SecureMailScreen({super.key, required this.api, CryptoSession? session})
      : session = session ?? CryptoSession.instance;

  final WachbuchApi api;
  final CryptoSession session;

  @override
  State<SecureMailScreen> createState() => _SecureMailScreenState();
}

class _SecureMailScreenState extends State<SecureMailScreen> {
  bool _loading = true;
  String? _error;
  MailInboxData? _inbox;

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
      final inbox = await widget.api.mailInbox();
      if (!mounted) return;
      setState(() {
        _inbox = inbox;
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

  void _openMail(int id, String title) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MailDetailScreen(
        api: widget.api,
        mailId: id,
        title: title,
        session: widget.session,
      ),
    ));
  }

  Future<void> _compose() async {
    final colleagues =
        _inbox?.colleagues.where((c) => c.hasKeys).toList(growable: false) ?? const [];
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MailComposeSheet(
        api: widget.api,
        session: widget.session,
        colleagues: colleagues,
      ),
    );
    if (sent == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.mailTitle),
          bottom: TabBar(tabs: [Tab(text: l.mailInboxTab), Tab(text: l.mailSentTab)]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _compose,
          icon: const Icon(Icons.edit_outlined),
          label: Text(l.mailCompose),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppLayout.contentMaxWidth(width)),
            child: _body(context, l),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l) {
    if (_loading && _inbox == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _inbox == null) {
      return Padding(padding: const EdgeInsets.all(16), child: ErrorBanner(message: _error!));
    }
    final inbox = _inbox!;
    return TabBarView(
      children: [
        _mailList(inbox.received, l, sender: true),
        _mailList(inbox.sent, l, sender: false),
      ],
    );
  }

  Widget _mailList(List<MailSummary> mails, AppLocalizations l, {required bool sender}) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: mails.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 64),
                  child: Center(child: Text(l.mailEmpty)),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: mails.length,
              itemBuilder: (context, index) {
                final mail = mails[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: Text(sender ? '${l.mailFrom}: ${mail.senderName}' : mail.senderName),
                    subtitle: mail.createdAt != null ? Text(_formatDate(mail.createdAt!)) : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openMail(mail.id, mail.senderName),
                  ),
                );
              },
            ),
    );
  }
}

class _MailComposeSheet extends StatefulWidget {
  const _MailComposeSheet({
    required this.api,
    required this.session,
    required this.colleagues,
  });

  final WachbuchApi api;
  final CryptoSession session;
  final List<ChatMemberKey> colleagues;

  @override
  State<_MailComposeSheet> createState() => _MailComposeSheetState();
}

class _MailComposeSheetState extends State<_MailComposeSheet> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final Set<int> _selected = {};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();
    if (body.isEmpty || _selected.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Self must hold a wrap too (the sender can re-read the mail). Fetch the
      // own public key/id from the identity bundle.
      final identity = await widget.api.chatIdentity();
      final selfId = (identity['user_id'] as num?)?.toInt();
      final selfPublicJwk = identity['public_jwk'];
      final recipients = <Map<String, dynamic>>[
        for (final colleague in widget.colleagues)
          if (_selected.contains(colleague.userId)) colleague.toRecipient(),
        if (selfId != null && selfPublicJwk != null)
          {'user_id': selfId, 'public_jwk': selfPublicJwk},
      ];
      final payload = E2ee.encryptForRecipients(
        jsonEncode({'subject': subject, 'body': body}),
        recipients,
      );
      await widget.api.sendMail(recipientIds: _selected.toList(), payload: payload);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _saving = false;
      });
    } on E2eeException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.mailCompose, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          Text(l.mailRecipients, style: Theme.of(context).textTheme.titleSmall),
          if (widget.colleagues.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l.mailNoColleagues),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final colleague in widget.colleagues)
                    CheckboxListTile(
                      value: _selected.contains(colleague.userId),
                      title: Text(colleague.label),
                      onChanged: _saving
                          ? null
                          : (checked) => setState(() {
                                if (checked == true) {
                                  _selected.add(colleague.userId);
                                } else {
                                  _selected.remove(colleague.userId);
                                }
                              }),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _subjectController,
            maxLength: 160,
            decoration: InputDecoration(labelText: l.mailSubject, counterText: ''),
          ),
          TextField(
            controller: _bodyController,
            maxLength: 2000,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: l.mailBody),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l.mailSend),
          ),
        ],
      ),
    );
  }
}

/// One encrypted mail, decrypted locally after the unlock gate.
class MailDetailScreen extends StatelessWidget {
  MailDetailScreen({
    super.key,
    required this.api,
    required this.mailId,
    required this.title,
    CryptoSession? session,
  }) : session = session ?? CryptoSession.instance;

  final WachbuchApi api;
  final int mailId;
  final String title;
  final CryptoSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: CryptoUnlockGate(
        api: api,
        session: session,
        builder: (context, privateJwk) =>
            _MailBody(api: api, mailId: mailId, privateJwk: privateJwk),
      ),
    );
  }
}

class _MailBody extends StatefulWidget {
  const _MailBody({required this.api, required this.mailId, required this.privateJwk});
  final WachbuchApi api;
  final int mailId;
  final Map<String, dynamic> privateJwk;

  @override
  State<_MailBody> createState() => _MailBodyState();
}

class _MailBodyState extends State<_MailBody> {
  bool _loading = true;
  String? _error;
  String _subject = '';
  String _body = '';
  bool _readable = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.api.mailDetail(widget.mailId);
      if (!detail.envelope.readable) {
        setState(() {
          _readable = false;
          _loading = false;
        });
        return;
      }
      final plain = E2ee.decryptEnvelope(detail.envelope.toEnvelope(), widget.privateJwk);
      String subject = '';
      String body = plain;
      try {
        final parsed = jsonDecode(plain);
        if (parsed is Map) {
          subject = (parsed['subject'] ?? '').toString();
          body = (parsed['body'] ?? '').toString();
        }
      } on FormatException {
        // Not JSON – show the plaintext as-is.
      }
      if (!mounted) return;
      setState(() {
        _subject = subject;
        _body = body;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on E2eeException {
      if (!mounted) return;
      setState(() {
        _readable = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Padding(padding: const EdgeInsets.all(16), child: ErrorBanner(message: _error!));
    }
    if (!_readable) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(l.chatUnreadable),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_subject.isNotEmpty) ...[
          Text(_subject, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
        ],
        Text(_body, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

String _formatDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}, ${two(date.hour)}:${two(date.minute)}';
}
