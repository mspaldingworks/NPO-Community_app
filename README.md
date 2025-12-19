# transconnect

TransConnect is a Flutter app.

## Getting Started

Run:

- `flutter pub get`
- `flutter run`

### Local Caches + Pins (local-only)

This app includes a **local-only caches + pins** feature:

- **Map provider**: OpenStreetMap tiles via `flutter_map`
- **Storage**: local SQLite (`sqflite`)
- **Description**: optional **Markdown** (`flutter_markdown`)
- **Admin-only**: set/move/delete pins and edit cache info (admin usernames are hardcoded in the app)
- **Per-cache password**: each cache is locked and must be unlocked by non-admin users

#### How it works

- Open **Caches** (Dashboard card)
- Tap a cache to open its details
- Each cache has a **single-pin map** (only that cache)
- Admins can place/move the pin by **long-pressing the map**
- Map includes **Zoom + / Zoom −** buttons
- Non-admins must enter the cache password to **unlock** it before viewing details/map

#### Seed / mock data

On first use, if the local caches table is empty, the app seeds a small Kentucky dataset from:

- `lib/data/pins.json`

The seed includes a couple of caches with **no pin placed yet** (null `lat/lng`) so you can test the flow.

Passwords are seeded for development via a `password` field in `lib/data/pins.json` and stored in SQLite as a hash.
Unlock state is remembered locally (via `SharedPreferences`) until an admin changes the cache password.

If you change the schema or want to reset local data during development, uninstall/reinstall the app (or clear app storage) to recreate the local database.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Project Structure

The project follows a structured directory layout to maintain organization and scalability.

- `lib`
    - `core`: Contains the core functionality of the application.
        - `constants`: Global constants, such as API endpoints.
        - `services`: Business logic and services that interact with APIs or databases (e.g., `AuthService`, `ChatService`).
        - `utils`: Miscellaneous utility functions and classes.
    - `data`: Hard-coded data used for testing or production (e.g., affirmation quotes).
    - `models`: Data models that represent the application's data structures (e.g., `User`, `Post`).
    - `navigation`: Navigation and routing logic, including the main app router and scaffold with navigation bar.
    - `pages`: UI screens and full-page views, organized by feature (e.g., `chat`, `community`, `profile`).
    - `theme`: Application-wide theme and styling information.
    - `widgets`: Reusable widgets that are shared across multiple screens.

This structure helps in separating concerns and making the codebase easier to navigate and maintain.