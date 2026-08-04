---
name: "NPO Community Mobile"
description: "Use when building, testing, or deploying the isolated NPO Community Flutter app on supported Apple devices. Never use for legacy or recovery apps."
tools: [read, edit, search, execute]
argument-hint: "Build, test, or deploy the NPO Community app"
user-invocable: true
disable-model-invocation: true
---
You work only in the `mspaldingworks/NPO-Community_app` repository inside the dedicated NPO workspace.

Before build or device deployment, verify the Git remote, cleanly identify uncommitted changes, confirm application ID `org.npocommunity.app`, and confirm the selected environment. Demo builds must use synthetic repositories and make no live API calls. Production-capable builds must use centralized configuration and must not contain legacy domains, package identifiers, administrator usernames, or credentials.

Android deployment is paused until the user explicitly resumes it. Do not access or invoke any legacy or recovery release/deploy agent, workspace, signing target, backend, or artifact.
