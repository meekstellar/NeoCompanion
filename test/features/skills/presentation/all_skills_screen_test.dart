import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neocompanion/features/skills/data/dto/character_skills.dart';
import 'package:neocompanion/features/skills/presentation/all_skills_screen.dart';
import 'package:neocompanion/features/skills/skill_providers.dart';

void main() {
  AllSkillsData buildData() {
    return const AllSkillsData(
      skills: CharacterSkills(
        totalSp: 12345,
        unallocatedSp: 0,
        skills: [
          SkillSummary(
            skillId: 3327,
            skillpointsInSkill: 256000,
            trainedSkillLevel: 5,
            activeSkillLevel: 5,
          ),
          SkillSummary(
            skillId: 3300,
            skillpointsInSkill: 45255,
            trainedSkillLevel: 4,
            activeSkillLevel: 4,
          ),
          SkillSummary(
            skillId: 3416,
            skillpointsInSkill: 8000,
            trainedSkillLevel: 3,
            activeSkillLevel: 3,
          ),
        ],
      ),
      names: {3327: 'Caldari Frigate', 3300: 'Gunnery', 3416: 'Navigation'},
    );
  }

  testWidgets('renders sorted alphabetically with counts', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allSkillsProvider(7).overrideWith((_) async => buildData()),
        ],
        child: const MaterialApp(home: AllSkillsScreen(characterId: 7)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Caldari Frigate'), findsOneWidget);
    expect(find.text('Gunnery'), findsOneWidget);
    expect(find.text('Navigation'), findsOneWidget);
    expect(find.text('3 of 3'), findsOneWidget);
  });

  testWidgets('filter narrows the list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allSkillsProvider(7).overrideWith((_) async => buildData()),
        ],
        child: const MaterialApp(home: AllSkillsScreen(characterId: 7)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'gun');
    await tester.pumpAndSettle();

    expect(find.text('Gunnery'), findsOneWidget);
    expect(find.text('Caldari Frigate'), findsNothing);
    expect(find.text('1 of 3'), findsOneWidget);
  });
}
