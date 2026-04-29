# neocompanion

Unofficial EVE Online companion app for iOS and Android. Built with Flutter against the current ESI.

## Flavors

Two entry points share a single bootstrap:

- `lib/main_dev.dart` — development flavor
- `lib/main_prod.dart` — production flavor

Configuration is injected at build time via `--dart-define` (no secrets in the repo):

| Variable | Required | Notes |
|---|---|---|
| `EVE_CLIENT_ID_DEV` | dev only | Client ID from developers.eveonline.com |
| `EVE_CLIENT_ID_PROD` | prod only | Client ID from developers.eveonline.com |
| `EVE_CALLBACK_SCHEME` | optional | Defaults to `eveauth-neocompanion` |
| `ESI_COMPATIBILITY_DATE` | optional | Pinned ESI compatibility date |
| `SENTRY_DSN` | optional | Crash reporting |

## Run

```bash
flutter run -t lib/main_dev.dart \
  --dart-define=EVE_CLIENT_ID_DEV=<your-client-id>

flutter run -t lib/main_prod.dart --release \
  --dart-define=EVE_CLIENT_ID_PROD=<your-client-id>
```
