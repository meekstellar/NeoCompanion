import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_providers.dart';
import 'core/config/app_config.dart';
import 'core/config/flavor.dart';
import 'core/notifications/notification_providers.dart';
import 'core/notifications/notification_service.dart';
import 'features/characters/presentation/character_list_screen.dart';
import 'features/skills/skill_notification_sync_scope.dart';

Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.forFlavor(flavor);
  final notifications = NotificationService();
  await notifications.initialize();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const NeoCompanionApp(),
    ),
  );
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
      home: const SkillNotificationSyncScope(child: CharacterListScreen()),
    );
  }
}
