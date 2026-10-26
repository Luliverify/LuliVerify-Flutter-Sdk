# Mobile Architecture

The merchant chooses native UI or hosted web presentation. Both consume the same
backend workflow, field/options, validation, pricing and evidence rules.

Public API -> session orchestration -> transport/backend contract parsers.
Native/hosted presenters depend on orchestration; device adapters own camera,
file selection, permissions and app links. Networking must not import widgets.
Do not use global mutable state for an active customer's session.

## Backend Gate

Existing browser launch and token guards are origin-bound. Native authentication
is NOT provided by this scaffold. Agree a mobile launch/exchange contract before
integrating HTTP. Never spoof Origin, relax browser security, embed merchant
secrets or invent a publishable-key mobile authorization scheme.

Retain backend required fields, capabilities, actions, revisions and role
requirements. Unsupported versions must fail explicitly. The merchant backend
and signed results remain authoritative; app callbacks report session state only.

## Security and Lifecycle

- Memory-only tokens by default, with no sensitive telemetry.
- App-private temporary evidence storage; deterministic cleanup.
- On-demand permissions, denied/restricted handling and cancellation.
- Serialized revision-aware submissions and controlled conflict recovery.
- Do not blindly retry consumed launch tickets or non-idempotent requests.
- Backend-controlled evidence reuse, expiry and liveness prerequisites.
- Register and validate hosted return links and session correlation.
- Returning to an app is not evidence of a passed verification.
- No silent fallback from liveness to a selfie or native UI to hosted web.

## Platform Decision

Validate the provider's native liveness support and evidence format before
selecting camera/file-picker/browser dependencies. Prefer maintained Flutter
plugins. Add a real platform plugin only for an actual Swift/Kotlin requirement.
Generated Android/iOS hosts do not demonstrate native build/camera compatibility.
