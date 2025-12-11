# transconnect

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

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