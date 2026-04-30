import '../../../core/network/esi_client.dart';
import 'dto/industry_job.dart';

class IndustryRepository {
  IndustryRepository(this._esi);

  final EsiClient _esi;

  /// Fetches every active and completed industry job for the
  /// character. The endpoint isn't paginated — ESI returns up to
  /// ~250 jobs in one shot — so a single GET is enough.
  Future<List<IndustryJob>> fetchJobs(int characterId) async {
    final res = await _esi.get<List<dynamic>>(
      '/characters/$characterId/industry/jobs/',
      characterId: characterId,
      queryParameters: {'include_completed': true},
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(IndustryJob.fromJson)
        .toList();
  }
}
