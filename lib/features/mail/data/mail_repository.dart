import '../../../core/network/esi_client.dart';
import 'dto/mail_header.dart';

class MailRepository {
  MailRepository(this._esi);

  final EsiClient _esi;

  /// First inbox page — most recent ~50 mails. Pagination via
  /// `last_mail_id` is post-MVP.
  Future<List<MailHeader>> fetchHeaders(int characterId) async {
    final res = await _esi.get<List<dynamic>>(
      '/characters/$characterId/mail/',
      characterId: characterId,
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(MailHeader.fromJson)
        .toList();
  }

  Future<MailBody> fetchBody(int characterId, int mailId) async {
    final res = await _esi.get<Map<String, dynamic>>(
      '/characters/$characterId/mail/$mailId/',
      characterId: characterId,
    );
    return MailBody.fromJson(res.data!);
  }
}
