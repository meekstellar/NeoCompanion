import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../data/dto/mail_header.dart';
import '../mail_providers.dart';

class MailScreen extends ConsumerWidget {
  const MailScreen({super.key, required this.characterId});

  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mailInboxProvider(characterId));
    return Scaffold(
      appBar: AppBar(title: const Text('Mail')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(describeEsiError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (inbox) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(mailInboxProvider(characterId)),
          child: inbox.headers.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  itemCount: inbox.headers.length,
                  separatorBuilder: (_, _) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final h = inbox.headers[i];
                    return _MailTile(
                      header: h,
                      senderName:
                          inbox.senderNames[h.fromId] ?? '#${h.fromId}',
                      onTap: () => _openBody(context, h),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _openBody(BuildContext context, MailHeader header) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MailBodySheet(
        characterId: characterId,
        header: header,
      ),
    );
  }
}

class _MailTile extends StatelessWidget {
  const _MailTile({
    required this.header,
    required this.senderName,
    required this.onTap,
  });

  final MailHeader header;
  final String senderName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: header.isRead
          ? const Icon(Icons.mark_email_read_outlined, size: 20)
          : Icon(
              Icons.mark_email_unread,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
      title: Text(
        header.subject.isEmpty ? '(no subject)' : header.subject,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: header.isRead
            ? null
            : const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '$senderName • ${_formatDate(header.timestamp)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class MailBodySheet extends ConsumerWidget {
  const MailBodySheet({
    super.key,
    required this.characterId,
    required this.header,
  });

  final int characterId;
  final MailHeader header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = ref.watch(mailBodyProvider(
      (characterId: characterId, mailId: header.mailId),
    ));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).hintColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              header.subject.isEmpty ? '(no subject)' : header.subject,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(header.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: body.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(describeEsiError(e)),
                data: (body) => SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    _stripHtml(body.body),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 96),
        Center(
          child: Column(
            children: [
              const Icon(Icons.mail_outline, size: 64),
              const SizedBox(height: 16),
              Text(
                'Inbox is empty',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatDate(DateTime d) =>
    DateFormat('MMM d, HH:mm').format(d.toLocal());

/// EVE mail bodies are HTML. We don't render rich content yet — the
/// regex strips tags and decodes the handful of entities the client
/// actually emits. Good enough for an inbox preview.
String _stripHtml(String html) {
  final withoutTags = html.replaceAll(RegExp(r'<[^>]+>'), '');
  return withoutTags
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}
