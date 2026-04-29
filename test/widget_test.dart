import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neocompanion/core/auth/auth_providers.dart';
import 'package:neocompanion/core/auth/token_set.dart';
import 'package:neocompanion/core/config/app_config.dart';
import 'package:neocompanion/core/config/flavor.dart';
import 'package:neocompanion/main.dart';

void main() {
  testWidgets('Empty character list shows the add-character CTA',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(AppConfig.forFlavor(Flavor.dev)),
          storedCharactersProvider
              .overrideWith((ref) => Future.value(<TokenSet>[])),
        ],
        child: const NeoCompanionApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add character'), findsOneWidget);
    expect(find.text('No characters yet'), findsOneWidget);
  });
}
