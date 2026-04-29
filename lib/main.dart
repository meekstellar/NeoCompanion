import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/config/flavor.dart';

Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.forFlavor(flavor);
  runApp(NeocomApp(config: config));
}

class NeocomApp extends StatelessWidget {
  const NeocomApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.isDev ? 'Neocom (dev)' : 'Neocom',
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
      home: const _PlaceholderScreen(),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Neocom')),
    );
  }
}
