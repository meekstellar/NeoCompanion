import '../../../core/notifications/notification_service.dart';
import '../data/dto/skill_queue_entry.dart';

/// Schedules a local notification for each queued skill at its
/// `finish_date` so the user is reminded the moment training completes.
///
/// iOS allows up to 64 pending notifications; we cap at 60 to leave room
/// for other notifications and for ad-hoc reminders. Non-training entries
/// (paused, missing dates, already past) are skipped.
///
/// Notification IDs are deterministic in (characterId, slot), so re-running
/// `schedule` removes the old set before placing the new one — calling it
/// after every queue refresh is safe and idempotent.
class SkillNotificationScheduler {
  SkillNotificationScheduler(this._service);

  final NotificationService _service;

  static const int _maxNotifications = 60;
  static const int _slotsPerCharacter = 100;
  static const int _characterIdMod = 1000000;

  int _slotBase(int characterId) =>
      (characterId % _characterIdMod) * _slotsPerCharacter;

  bool _ownsId(int characterId, int id) {
    final base = _slotBase(characterId);
    return id >= base && id < base + _slotsPerCharacter;
  }

  /// Returns the IDs that were scheduled this call.
  Future<List<int>> schedule({
    required int characterId,
    required List<SkillQueueEntry> queue,
    required Map<int, String> skillNames,
    DateTime? now,
  }) async {
    final reference = now ?? DateTime.now();
    await _cancelExistingFor(characterId);

    final base = _slotBase(characterId);
    final scheduled = <int>[];

    for (final entry in queue) {
      if (scheduled.length >= _maxNotifications) break;
      if (entry.isPaused) continue;
      final finish = entry.finishDate;
      if (finish == null || !finish.isAfter(reference)) continue;

      final id = base + scheduled.length;
      final name = skillNames[entry.skillId] ?? 'Skill #${entry.skillId}';

      await _service.scheduleAt(
        id: id,
        title: '$name ${_roman(entry.finishedLevel)} finished training',
        body: 'Your skill is ready.',
        when: finish,
      );
      scheduled.add(id);
    }

    return scheduled;
  }

  Future<void> cancelFor(int characterId) => _cancelExistingFor(characterId);

  Future<void> _cancelExistingFor(int characterId) async {
    final pending = await _service.pending();
    for (final p in pending) {
      if (_ownsId(characterId, p.id)) {
        await _service.cancel(p.id);
      }
    }
  }
}

String _roman(int level) =>
    const ['', 'I', 'II', 'III', 'IV', 'V'][level.clamp(0, 5)];
