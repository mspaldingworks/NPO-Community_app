# FOSS Community App Template

This is a generalized, Google-free Flutter client template derived from the architecture shape of a capability-based community app.

## Quick start

```bash
flutter pub get
flutter run --dart-define=APP_ENV=demo --dart-define=API_ORIGIN=https://demo.invalid
```

## Environments

- `APP_ENV=demo`: fully synthetic in-memory data, no HTTP, no WebSocket, no remote media requests.
- `APP_ENV=local`: points to your local backend origin.
- `APP_ENV=production`: enforces HTTPS API origin.

## Rebranding checklist

- Rename package in `pubspec.yaml`.
- Update app names in platform folders (`android`, `ios`, `web`, desktop manifests).
- Update bundle/application IDs from `org.fosscommunity.app`.
- Replace placeholder icons and colors with your project branding.

## Google-free integrations

- **Media**: MinIO/S3-compatible presigned URLs from backend APIs.
- **Realtime delivery**: WebSocket (`/ws/`) primary channel.
- **Optional notifications**: UnifiedPush/ntfy adapter (off by default).
- **Analytics**: Matomo adapter, opt-in only, no-op by default.
- **Error reporting**: `sentry_flutter`, disabled unless `SENTRY_DSN` is provided.
- **Maps**: `flutter_map` + OpenStreetMap-compatible tiles from backend public config.

`flutter_map` is used instead of `maplibre_gl` to keep one reusable widget path across iOS, Android, web, and desktop with minimal native setup in template form.

## Distribution note

Android distribution is intended for F-Droid and direct APK channels. This template avoids Firebase, FCM, and Google Play Services dependencies.

See `docs/GOOGLE-FREE.md` for dependency and licensing notes.
