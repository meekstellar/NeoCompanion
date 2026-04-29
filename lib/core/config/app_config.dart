import 'flavor.dart';

class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.eveClientId,
    required this.eveCallbackScheme,
    required this.esiCompatibilityDate,
    required this.sentryDsn,
  });

  final Flavor flavor;
  final String eveClientId;
  final String eveCallbackScheme;
  final String esiCompatibilityDate;
  final String sentryDsn;

  static AppConfig forFlavor(Flavor flavor) {
    const devClientId = String.fromEnvironment('EVE_CLIENT_ID_DEV');
    const prodClientId = String.fromEnvironment('EVE_CLIENT_ID_PROD');
    const callbackScheme = String.fromEnvironment(
      'EVE_CALLBACK_SCHEME',
      defaultValue: 'eveauth-neocompanion',
    );
    const compatibilityDate = String.fromEnvironment(
      'ESI_COMPATIBILITY_DATE',
      defaultValue: '2026-04-29',
    );
    const sentryDsn = String.fromEnvironment('SENTRY_DSN');

    return AppConfig(
      flavor: flavor,
      eveClientId: flavor == Flavor.dev ? devClientId : prodClientId,
      eveCallbackScheme: callbackScheme,
      esiCompatibilityDate: compatibilityDate,
      sentryDsn: sentryDsn,
    );
  }

  bool get isDev => flavor == Flavor.dev;
}
