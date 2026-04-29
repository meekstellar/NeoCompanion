import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neocompanion/features/skills/data/dto/character_skills.dart';
import 'package:neocompanion/features/skills/data/dto/skill_queue_entry.dart';
import 'package:neocompanion/features/skills/presentation/skill_queue_screen.dart';
import 'package:neocompanion/features/skills/skill_providers.dart';

void main() {
  testWidgets('renders skill names, progress, and queue total', (tester) async {
    final now = DateTime.now();
    final data = SkillQueueData(
      queue: [
        SkillQueueEntry(
          skillId: 3327,
          queuePosition: 0,
          finishedLevel: 5,
          levelStartSp: 45255,
          levelEndSp: 256000,
          trainingStartSp: 45255,
          startDate: now.subtract(const Duration(hours: 1)),
          finishDate: now.add(const Duration(hours: 9)),
        ),
        SkillQueueEntry(
          skillId: 3300,
          queuePosition: 1,
          finishedLevel: 4,
          levelStartSp: 8000,
          levelEndSp: 45255,
          trainingStartSp: 8000,
          startDate: now.add(const Duration(hours: 9)),
          finishDate: now.add(const Duration(hours: 12)),
        ),
      ],
      skills: const CharacterSkills(
        totalSp: 95000000,
        unallocatedSp: 50000,
        skills: [],
      ),
      skillNames: const {3327: 'Caldari Frigate', 3300: 'Gunnery'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skillQueueProvider(42).overrideWith((_) async => data),
        ],
        child: const MaterialApp(
          home: SkillQueueScreen(characterId: 42),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Caldari Frigate V'), findsOneWidget);
    expect(find.text('Gunnery IV'), findsOneWidget);
    expect(find.text('QUEUE EMPTIES IN'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('Queued'), findsOneWidget);
  });

  testWidgets('shows empty state when queue is empty', (tester) async {
    final data = const SkillQueueData(
      queue: [],
      skills: CharacterSkills(totalSp: 0, unallocatedSp: 0, skills: []),
      skillNames: {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skillQueueProvider(42).overrideWith((_) async => data),
        ],
        child: const MaterialApp(
          home: SkillQueueScreen(characterId: 42),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Queue is empty'), findsOneWidget);
  });
}
