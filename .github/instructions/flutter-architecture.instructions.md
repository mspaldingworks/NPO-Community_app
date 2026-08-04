---
description: "Use when changing NPO Community Flutter models, services, routing, screens, authentication, demo mode, platform identity, or mobile build configuration."
applyTo: ["lib/**", "test/**", "pubspec.yaml", "android/**", "ios/**", "web/**", "macos/**", "linux/**", "windows/**"]
---
# Flutter Architecture Requirements

- Parse the session bootstrap into typed roles, capabilities, tier, memberships, and feature flags.
- Hide unavailable navigation for clarity, but handle API `403` responses as the actual authorization boundary.
- Disable all writes centrally during Role Preview and exit preview on backgrounding or session refresh.
- Do not place preview role in headers, URLs, request bodies, or persisted storage.
- Keep demo and live dependencies separate at the composition root; synthetic demo data must be obviously fictional.
- Remove legacy endpoints, forms, calendars, maps, assets, package IDs, and hardcoded administrator usernames instead of aliasing them.
