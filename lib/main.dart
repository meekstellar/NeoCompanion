import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_providers.dart';
import 'core/config/app_config.dart';
import 'core/config/flavor.dart';
import 'core/demo/demo_mode.dart';
import 'core/demo/demo_overrides.dart';
import 'core/diagnostics/error_reporter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'core/notifications/notification_providers.dart';
import 'core/notifications/notification_service.dart';
import 'core/storage/app_database.dart';
import 'core/types/presentation/item_database_gate.dart';
import 'core/types/types_database.dart';
import 'core/types/types_database_providers.dart';
import 'core/ui/offline_banner.dart';
import 'features/characters/presentation/character_list_screen.dart';
import 'features/fittings/local_fitting_providers.dart';
import 'features/skills/skill_notification_sync_scope.dart';

Future<void> bootstrap(Flavor flavor) async {
  // runZonedGuarded captures the entire app's uncaught async errors and
  // routes them through ErrorReporter, the same sink that FlutterError
  // and PlatformDispatcher use. A future Sentry/Crashlytics integration
  // only needs to swap the sink — call sites stay untouched.
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final config = AppConfig.forFlavor(flavor);
    ErrorReporter.install(release: !config.isDev);

    final notifications = NotificationService();
    await notifications.initialize();

    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'sde.db');
    final sqlite = await openExistingSdeDatabase(dbPath);
    final typesDb = TypesDatabase(sqlite, path: dbPath);
    await typesDb.load();

    final appDb = await openAppDatabase(p.join(docsDir.path, 'app.db'));

    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          notificationServiceProvider.overrideWithValue(notifications),
          typesDatabaseProvider.overrideWithValue(typesDb),
          appDatabaseProvider.overrideWithValue(appDb),
          if (kDemoMode) ...demoOverrides(),
        ],
        child: const NeoCompanionApp(),
      ),
    );
  }, (error, stack) {
    ErrorReporter.instance.report(error, stack);
  });
}

class NeoCompanionApp extends ConsumerWidget {
  const NeoCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return MaterialApp(
      title: config.isDev ? 'NeoCompanion (dev)' : 'NeoCompanion',
      debugShowCheckedModeBanner: config.isDev,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6FB5FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const ItemDatabaseGate(
        child: OfflineBanner(
          child: SkillNotificationSyncScope(child: CharacterListScreen()),
        ),
      ),
    );
  }
}
