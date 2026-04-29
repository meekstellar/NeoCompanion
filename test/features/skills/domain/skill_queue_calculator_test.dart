import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/features/skills/data/dto/skill_queue_entry.dart';
import 'package:neocompanion/features/skills/domain/skill_queue_calculator.dart';

void main() {
  const calc = SkillQueueCalculator();

  SkillQueueEntry entry({
    DateTime? start,
    DateTime? finish,
    int spStart = 0,
    int spEnd = 100000,
    int? trainingStartSp,
  }) {
    return SkillQueueEntry(
      skillId: 3327,
      queuePosition: 0,
      finishedLevel: 5,
      levelStartSp: spStart,
      levelEndSp: spEnd,
      trainingStartSp: trainingStartSp,
      startDate: start,
      finishDate: finish,
    );
  }

  group('progressOf', () {
    test('returns paused state when entry has no dates', () {
      final p = calc.progressOf(entry(), DateTime(2026));
      expect(p.state, SkillTrainingState.paused);
      expect(p.progressFraction, 0);
      expect(p.remaining, Duration.zero);
    });

    test('returns notYetStarted when now is before start_date', () {
      final start = DateTime(2026, 5, 1);
      final finish = DateTime(2026, 5, 2);
      final p = calc.progressOf(
        entry(start: start, finish: finish, spStart: 1000),
        DateTime(2026, 4, 30),
      );
      expect(p.state, SkillTrainingState.notYetStarted);
      expect(p.progressFraction, 0);
      expect(p.currentSp, 1000);
    });

    test('interpolates SP and fraction at the midpoint of the window', () {
      final start = DateTime.utc(2026, 5, 1, 0);
      final finish = DateTime.utc(2026, 5, 1, 10);
      final now = DateTime.utc(2026, 5, 1, 5);
      final p = calc.progressOf(
        entry(start: start, finish: finish, spStart: 0, spEnd: 100000),
        now,
      );
      expect(p.state, SkillTrainingState.training);
      expect(p.progressFraction, closeTo(0.5, 1e-9));
      expect(p.currentSp, 50000);
      expect(p.remaining, const Duration(hours: 5));
    });

    test('uses training_start_sp when present', () {
      final start = DateTime.utc(2026, 5, 1);
      final finish = DateTime.utc(2026, 5, 1, 10);
      final now = DateTime.utc(2026, 5, 1, 5);
      final p = calc.progressOf(
        entry(
          start: start,
          finish: finish,
          spStart: 45255,
          spEnd: 256000,
          trainingStartSp: 100000,
        ),
        now,
      );
      // Halfway between 100k and 256k = 178k
      expect(p.currentSp, 178000);
    });

    test('returns completed when now is at or past finish_date', () {
      final start = DateTime(2026, 5, 1);
      final finish = DateTime(2026, 5, 2);
      final p = calc.progressOf(
        entry(start: start, finish: finish, spStart: 0, spEnd: 100000),
        DateTime(2026, 5, 3),
      );
      expect(p.state, SkillTrainingState.completed);
      expect(p.progressFraction, 1);
      expect(p.currentSp, 100000);
      expect(p.remaining, Duration.zero);
    });
  });

  group('queueTimeRemaining', () {
    test('returns zero for an empty queue', () {
      expect(calc.queueTimeRemaining([], DateTime(2026)), Duration.zero);
    });

    test('returns zero for a fully-paused queue', () {
      final entries = [entry(), entry()];
      expect(
        calc.queueTimeRemaining(entries, DateTime(2026)),
        Duration.zero,
      );
    });

    test('returns the gap between now and the last finish date', () {
      final now = DateTime.utc(2026, 5, 1);
      final entries = [
        entry(
          start: now,
          finish: now.add(const Duration(hours: 1)),
        ),
        entry(
          start: now.add(const Duration(hours: 1)),
          finish: now.add(const Duration(hours: 5)),
        ),
        entry(
          start: now.add(const Duration(hours: 5)),
          finish: now.add(const Duration(days: 2)),
        ),
      ];
      expect(
        calc.queueTimeRemaining(entries, now),
        const Duration(days: 2),
      );
    });

    test('returns zero when all finish dates are in the past', () {
      final past = DateTime(2020);
      expect(
        calc.queueTimeRemaining(
          [entry(start: past, finish: past.add(const Duration(hours: 1)))],
          DateTime(2026),
        ),
        Duration.zero,
      );
    });
  });
}
