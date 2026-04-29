# neocompanion

Unofficial EVE Online companion app for iOS and Android. Built with Flutter against the current ESI.

## Flavors

Two entry points share a single bootstrap:

- `lib/main_dev.dart` — development flavor
- `lib/main_prod.dart` — production flavor

Configuration is injected at build time via `--dart-define-from-file`. The
real `config/dev.json` and `config/prod.json` files are gitignored; commit
only the `*.example` templates.

| Variable | Required | Notes |
|---|---|---|
| `EVE_CLIENT_ID_DEV` | dev only | Client ID from developers.eveonline.com |
| `EVE_CLIENT_ID_PROD` | prod only | Client ID from developers.eveonline.com |
| `EVE_CALLBACK_SCHEME` | optional | Defaults to `eveauth-neocompanion` |
| `ESI_COMPATIBILITY_DATE` | optional | Pinned ESI compatibility date |
| `SENTRY_DSN` | optional | Crash reporting |

## Setup

```bash
cp config/dev.json.example config/dev.json
# fill in EVE_CLIENT_ID_DEV with your client id
```

## Run

```bash
flutter run -t lib/main_dev.dart --dart-define-from-file=config/dev.json

flutter run -t lib/main_prod.dart --release \
  --dart-define-from-file=config/prod.json
```
