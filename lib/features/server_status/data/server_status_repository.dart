import 'package:dio/dio.dart';

import '../../../core/network/esi_client.dart';
import 'dto/server_status.dart';

class ServerStatusRepository {
  ServerStatusRepository(this._esi);

  final EsiClient _esi;

  /// Fetches the cluster status. ESI returns 503 during the daily
  /// downtime; surface that as `ServerStatus.offline` so the UI gets
  /// a clean answer either way and only network-level failures
  /// propagate.
  Future<ServerStatus> fetchStatus() async {
    try {
      final res = await _esi.get<Map<String, dynamic>>('/status/');
      return ServerStatus.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 503) return ServerStatus.offline;
      rethrow;
    }
  }
}
