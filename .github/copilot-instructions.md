# NPO Community Flutter Guidelines

## Product Boundary
- This is the stakeholder-only NPO Community app. It is independent of all legacy and recovery projects.
- The app serves adult volunteers, donors, alumni, event leads, mentors, chapter leads, partner leads, committee and board members, moderators, interns, staff, and admins.
- Do not add participants, case management, P3 data, minors, guardians, service-delivery notes, or demographic/identity profile fields.
- Use package name `npo_community`, visible name `NPO Community`, application IDs `org.npocommunity.app`, and deep links under `npo://`.

## Architecture And Privacy
- Server permissions are authoritative. Client capability checks only control rendering and command availability.
- Centralize rendering decisions in a typed capability service. Do not gate by username, `isStaff`, or ad hoc role strings.
- Store tokens only in `flutter_secure_storage`; SharedPreferences is for non-sensitive UI preferences.
- Keep notification text generic and require authentication before resolving deep links.
- Role Preview is in-memory, read-only, visibly bannered, and never sent to the API. Do not implement user impersonation.

## Environments
- All HTTP, WebSocket, and media origins come from one typed build configuration.
- Demo builds use synthetic repositories and make zero live API calls. Demo mode must not inject an admin into production authentication.
- Never commit signing secrets, Firebase private configuration, tokens, generated build outputs, or production data.

## Validation
- Run `dart format`, `flutter analyze`, and focused tests after changes.
- Verify responsive behavior and privacy-sensitive states on supported phone layouts.
- Android deployment remains paused until explicitly resumed.
