# Emerge Kentucky Alumni

Alumni directory and community app for the Emerge Kentucky program. Alumni CRM
data is served from the API's NGP VAN integration; the app never talks to VAN
directly. The current release target is an iOS demo backed exclusively by
synthetic, in-memory data.

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

## Login screen testing

- Use only disposable debug accounts that were explicitly created or reset for QA.
  Do not reuse production credentials, and do not expect the app or Django backend
  to expose existing passwords. Django stores password hashes, not recoverable
  plaintext passwords.
- Keep `API_ORIGIN` configurable per device so the login screen talks to a
  reachable backend:

```sh
# iOS simulator on the same Mac
flutter run \
  --dart-define=APP_ENV=local \
  --dart-define=API_ORIGIN=http://127.0.0.1:8000

# Android emulator talking to the host machine
flutter run \
  --dart-define=APP_ENV=local \
  --dart-define=API_ORIGIN=http://10.0.2.2:8000

# Physical device on the same LAN as the backend
flutter run \
  --dart-define=APP_ENV=local \
  --dart-define=API_ORIGIN=http://192.168.1.50:8000

# Physical device against the live backend
flutter run \
  --dart-define=APP_ENV=production \
  --dart-define=API_ORIGIN=https://api.lyg-community.com
```

- `API_ORIGIN` is baked in at build time, so a running app keeps whatever origin
  it was compiled with. Changing it means a rebuild, not a hot reload.
- `APP_ENV=production` requires an HTTPS origin; `AppConfig` throws otherwise.

- If login fails with an unreachable API message, confirm the backend is running
  and update `--dart-define=API_ORIGIN=...` to a host the simulator or device
  can actually reach.

Android deployment remains paused.
