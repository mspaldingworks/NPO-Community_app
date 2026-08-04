# NPO Community

Stakeholder operations app for NPO Community. The current release target is an
iOS demo backed exclusively by synthetic, in-memory data.

## Demo

```sh
flutter pub get
flutter run \
  --dart-define=APP_ENV=demo \
  --dart-define=API_ORIGIN=https://demo.invalid
```

Demo mode must not make HTTP, WebSocket, or remote media requests.

## Validation

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test \
  --dart-define=APP_ENV=demo \
  --dart-define=API_ORIGIN=https://demo.invalid
```

Android deployment remains paused.
