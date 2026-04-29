import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neocompanion/core/notifications/notification_service.dart';
import 'package:neocompanion/features/skills/data/dto/skill_queue_entry.dart';
import 'package:neocompanion/features/skills/domain/skill_notification_scheduler.dart';

class _ScheduledCall {
  _ScheduledCall(this.id, this.title, this.body, this.when);
  final int id;
  final String title;
  final String body;
  final DateTime when;
}

class _FakeNotificationService implements NotificationService {
  final List<_ScheduledCall> scheduled = [];
  final List<int> canceled = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    scheduled.add(_ScheduledCall(id, title, body, when));
  }

  @override
  Future<void> cancel(int id) async {
    canceled.add(id);
    scheduled.removeWhere((s) => s.id == id);
  }

  @override
  Future<void> cancelAll() async {
    canceled.addAll(scheduled.map((s) => s.id));
    scheduled.clear();
  }

  @override
  Future<List<PendingNotificationRequest>> pending() async {
    return scheduled
        .map((s) => PendingNotificationRequest(s.id, s.title, s.body, null))
        .toList();
  }
}

void main() {
  late _FakeNotificationService fake;
  late SkillNotificationScheduler scheduler;
  final now = DateTime.utc(2026, 5, 1, 12);

  setUp(() {
    fake = _FakeNotificationService();
    scheduler = SkillNotificationScheduler(fake);
  });

  SkillQueueEntry entry({
    required int skillId,
    required int position,
    DateTime? finish,
    int level = 5,
  }) {
    final start = finish?.subtract(const Duration(hours: 1));
    return SkillQueueEntry(
      skillId: skillId,
      queuePosition: position,
      finishedLevel: level,
      levelStartSp: 0,
      levelEndSp: 100000,
      trainingStartSp: 0,
      startDate: start,
      finishDate: finish,
    );
  }

  test('schedules one notification per future entry', () async {
    final ids = await scheduler.schedule(
      characterId: 90000001,
      queue: [
        entry(
          skillId: 3327,
          position: 0,
          finish: now.add(const Duration(hours: 1)),
        ),
        entry(
          skillId: 3300,
          position: 1,
          finish: now.add(const Duration(hours: 5)),
          level: 4,
        ),
      ],
      skillNames: const {3327: 'Caldari Frigate', 3300: 'Gunnery'},
      now: now,
    );

    expect(ids.length, 2);
    expect(fake.scheduled.length, 2);
    expect(fake.scheduled[0].title, 'Caldari Frigate V finished training');
    expect(fake.scheduled[1].title, 'Gunnery IV finished training');
  });

  test('skips paused entries and finishes already in the past', () async {
    final ids = await scheduler.schedule(
      characterId: 90000001,
      queue: [
        entry(skillId: 1, position: 0), // paused (no dates)
        entry(
          skillId: 2,
          position: 1,
          finish: now.subtract(const Duration(hours: 1)),
        ),
        entry(
          skillId: 3,
          position: 2,
          finish: now.add(const Duration(hours: 1)),
        ),
      ],
      skillNames: const {3: 'Living'},
      now: now,
    );

    expect(ids.length, 1);
    expect(fake.scheduled.single.title, 'Living V finished training');
  });

  test('caps at 60 entries', () async {
    final queue = List.generate(
      80,
      (i) => entry(
        skillId: 100 + i,
        position: i,
        finish: now.add(Duration(hours: i + 1)),
      ),
    );
    await scheduler.schedule(
      characterId: 90000001,
      queue: queue,
      skillNames: const {},
      now: now,
    );
    expect(fake.scheduled.length, 60);
  });

  test('rescheduling cancels the previous set for the same character',
      () async {
    await scheduler.schedule(
      characterId: 90000001,
      queue: [
        entry(skillId: 1, position: 0, finish: now.add(const Duration(hours: 1))),
        entry(skillId: 2, position: 1, finish: now.add(const Duration(hours: 2))),
      ],
      skillNames: const {},
      now: now,
    );
    expect(fake.scheduled.length, 2);

    await scheduler.schedule(
      characterId: 90000001,
      queue: [
        entry(skillId: 3, position: 0, finish: now.add(const Duration(hours: 3))),
      ],
      skillNames: const {},
      now: now,
    );
    expect(fake.scheduled.length, 1);
    expect(fake.canceled.length, 2);
  });

  test('different characters do not cancel each other', () async {
    await scheduler.schedule(
      characterId: 90000001,
      queue: [
        entry(skillId: 1, position: 0, finish: now.add(const Duration(hours: 1))),
      ],
      skillNames: const {},
      now: now,
    );
    await scheduler.schedule(
      characterId: 90000002,
      queue: [
        entry(skillId: 2, position: 0, finish: now.add(const Duration(hours: 1))),
      ],
      skillNames: const {},
      now: now,
    );
    expect(fake.scheduled.length, 2);
    expect(fake.canceled, isEmpty);
  });
}
