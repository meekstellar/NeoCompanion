import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import '../characters/character_providers.dart';
import 'data/dto/mail_header.dart';
import 'data/mail_repository.dart';

final mailRepositoryProvider = Provider<MailRepository>((ref) {
  return MailRepository(ref.watch(esiClientProvider));
});

class MailInbox {
  const MailInbox({required this.headers, required this.senderNames});

  final List<MailHeader> headers;
  final Map<int, String> senderNames;
}

final mailInboxProvider =
    FutureProvider.family<MailInbox, int>((ref, characterId) async {
  final mail = ref.watch(mailRepositoryProvider);
  final character = ref.watch(characterRepositoryProvider);

  final headers = await mail.fetchHeaders(characterId);
  final senderIds = {
    for (final h in headers)
      if (h.fromId > 0) h.fromId,
  }.toList();

  Map<int, String> senderNames = const {};
  if (senderIds.isNotEmpty) {
    try {
      final resolved = await character.resolveNames(senderIds);
      senderNames = {for (final n in resolved) n.id: n.name};
    } catch (_) {
      // Fall back to raw IDs.
    }
  }

  return MailInbox(headers: headers, senderNames: senderNames);
});

final mailBodyProvider =
    FutureProvider.family<MailBody, ({int characterId, int mailId})>(
  (ref, args) async {
    return ref
        .watch(mailRepositoryProvider)
        .fetchBody(args.characterId, args.mailId);
  },
);
