/// One snapshot of the EVE Online cluster as reported by ESI's
/// `/status/` endpoint. The response is unauthenticated and ESI caches
/// it for ~30 seconds.
///
/// During the daily downtime ESI returns 503 instead of a body — the
/// repository surfaces that as an `online: false` snapshot so callers
/// don't have to reason about HTTP codes.
class ServerStatus {
  const ServerStatus({
    required this.online,
    required this.players,
    required this.startTime,
    required this.vip,
  });

  /// `true` when ESI is willing to talk to us about the cluster, i.e.
  /// the response was a normal 200. `false` during downtime / outages.
  final bool online;

  /// Currently logged-in pilot count. Zero when [online] is false.
  final int players;

  /// When the cluster came up after the last downtime. Null when
  /// offline or when ESI omits the field.
  final DateTime? startTime;

  /// VIP-only mode (after big patches CCP sometimes restricts logins
  /// to subscription accounts that they invited back). False most of
  /// the time, including the entire offline state.
  final bool vip;

  static const offline = ServerStatus(
    online: false,
    players: 0,
    startTime: null,
    vip: false,
  );

  factory ServerStatus.fromJson(Map<String, dynamic> json) {
    final startRaw = json['start_time'] as String?;
    return ServerStatus(
      online: true,
      players: (json['players'] as num?)?.toInt() ?? 0,
      startTime: startRaw == null ? null : DateTime.tryParse(startRaw),
      vip: json['vip'] as bool? ?? false,
    );
  }
}
