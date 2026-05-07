/// Single source of truth for whether the app should run in demo /
/// screenshot mode. Toggled at build time via
/// `--dart-define=DEMO_MODE=true`.
///
/// In demo mode every ESI-backed provider is replaced with seeded
/// fixtures (see `demo_data.dart` / `demo_overrides.dart`) so the app
/// can be exercised — and screenshotted — without a real character or
/// network access.
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE');
