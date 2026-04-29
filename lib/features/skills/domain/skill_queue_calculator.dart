import '../data/dto/skill_queue_entry.dart';

enum SkillTrainingState { paused, notYetStarted, training, completed }

class SkillProgress {
  const SkillProgress({
    required this.entry,
    required this.state,
    required this.currentSp,
    required this.progressFraction,
    required this.remaining,
  });

  final SkillQueueEntry entry;
  final SkillTrainingState state;
  final int currentSp;
  final double progressFraction;
  final Duration remaining;
}

/// Pure interpolation of where a skill is between start_date and finish_date.
/// ESI does not return live progress; the UI must reconstruct it from the
/// timestamps and the SP range. All inputs are immutable, no side effects.
class SkillQueueCalculator {
  const SkillQueueCalculator();

  SkillProgress progressOf(SkillQueueEntry entry, DateTime now) {
    if (entry.isPaused) {
      return SkillProgress(
        entry: entry,
        state: SkillTrainingState.paused,
        currentSp: entry.trainingStartSp ?? entry.levelStartSp,
        progressFraction: 0,
        remaining: Duration.zero,
      );
    }

    final start = entry.startDate!;
    final finish = entry.finishDate!;
    final spStart = entry.trainingStartSp ?? entry.levelStartSp;
    final spEnd = entry.levelEndSp;

    if (!now.isAfter(start)) {
      return SkillProgress(
        entry: entry,
        state: SkillTrainingState.notYetStarted,
        currentSp: spStart,
        progressFraction: 0,
        remaining: finish.difference(now),
      );
    }

    if (!now.isBefore(finish)) {
      return SkillProgress(
        entry: entry,
        state: SkillTrainingState.completed,
        currentSp: spEnd,
        progressFraction: 1,
        remaining: Duration.zero,
      );
    }

    final totalMicros = finish.difference(start).inMicroseconds;
    final elapsedMicros = now.difference(start).inMicroseconds;
    final fraction = elapsedMicros / totalMicros;
    final currentSp = spStart + ((spEnd - spStart) * fraction).round();

    return SkillProgress(
      entry: entry,
      state: SkillTrainingState.training,
      currentSp: currentSp,
      progressFraction: fraction,
      remaining: finish.difference(now),
    );
  }

  /// Time until the last entry in [entries] completes. [Duration.zero] if the
  /// queue is empty or fully paused.
  Duration queueTimeRemaining(List<SkillQueueEntry> entries, DateTime now) {
    final finishes = entries
        .map((e) => e.finishDate)
        .whereType<DateTime>()
        .toList();
    if (finishes.isEmpty) return Duration.zero;
    finishes.sort();
    final last = finishes.last;
    return last.isAfter(now) ? last.difference(now) : Duration.zero;
  }
}
