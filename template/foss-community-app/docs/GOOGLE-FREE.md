# Google-Free Dependency Manifest

This template intentionally excludes Google Play Services, Firebase, FCM, Google Maps, NGP VAN/EveryAction, Asana, and Google Drive integrations.

## Runtime dependencies

| Package | License | Why included |
| --- | --- | --- |
| flutter / material | BSD-3-Clause | Core UI framework |
| cupertino_icons | MIT | Icon pack |
| go_router | BSD-3-Clause | Navigation/routing |
| provider | MIT | State and dependency injection |
| scoped_model | MIT | Legacy-compatible scoped state option |
| adaptive_theme | MIT | Theme mode persistence |
| http | BSD-3-Clause | REST client |
| web_socket_channel | BSD-3-Clause | Realtime WebSocket delivery |
| shared_preferences | BSD-3-Clause | Non-sensitive local preferences |
| flutter_secure_storage | BSD-3-Clause | Secure token storage |
| path_provider | BSD-3-Clause | File-system paths |
| image_picker | BSD-3-Clause | Local media selection |
| video_player | BSD-3-Clause | Video playback |
| cached_network_image | MIT | Efficient image loading |
| file_selector | BSD-3-Clause | Desktop/web file picking |
| flutter_markdown | BSD-3-Clause | Markdown rendering |
| emoji_picker_flutter | BSD-3-Clause | Emoji input UI |
| table_calendar | MIT | Calendar UI scaffold |
| intl | BSD-3-Clause | Localization/date formatting |
| timeago | MIT | Relative time formatting |
| url_launcher | BSD-3-Clause | External URL handling |
| logger | MIT | Structured logging |
| json_annotation | BSD-3-Clause | JSON model annotations |
| sentry_flutter | MIT | Error reporting (GlitchTip/Sentry-compatible) |
| flutter_map | BSD-3-Clause | Map rendering without Google APIs |
| latlong2 | MIT | Latitude/longitude models |

## Dev dependencies

| Package | License | Why included |
| --- | --- | --- |
| flutter_test | BSD-3-Clause | Testing framework |
| flutter_lints | BSD-3-Clause | Static analysis defaults |
| mockito | BSD-3-Clause | Test doubles |
| build_runner | BSD-3-Clause | Code generation runner |
| json_serializable | BSD-3-Clause | JSON serialization generation |

## Distribution posture

- Android distribution target: F-Droid and direct APK channels.
- No Google-only runtime services are required by this project.
- Backend-provided config determines Matomo and map tile endpoints.
