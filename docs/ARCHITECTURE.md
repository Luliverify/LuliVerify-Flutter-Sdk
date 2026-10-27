# Mobile Architecture

The merchant chooses native UI or hosted web presentation. Both consume the same
backend workflow, field/options, validation, pricing and evidence rules.

Public API -> session orchestration -> transport/backend contract parsers.
Native/hosted presenters depend on orchestration; device adapters own camera,
file selection, permissions and app links. Networking must not import widgets.
Do not use global mutable state for an active customer's session.

## Backend Gate

Browser launch/token guards remain origin-bound. The accompanying backend change
adds publishable-key mobile creation and a separate native access channel with
short-lived, one-use tickets. Optional merchant-server grants remain supported.
Deploy that change before using the implemented native HTTP adapter.
Never spoof Origin, relax browser guards or embed merchant keys in an app.

Retain backend required fields, capabilities, actions, revisions and role
requirements. Unsupported versions must fail explicitly. The merchant backend
and signed results remain authoritative; app callbacks report session state only.

## Security and Lifecycle

- Memory-only tokens by default, with no sensitive telemetry.
- Temporary evidence lifetime must be controlled; upload buffers are cleared by
  the built-in screen and camera cache cleanup is handled by the picker adapter.
- On-demand permissions, denied/restricted handling and cancellation.
- Serialized revision-aware submissions and controlled conflict recovery.
- Do not blindly retry consumed launch tickets or non-idempotent requests.
- Backend-controlled evidence reuse, expiry and liveness prerequisites.
- Register and validate hosted return links and session correlation.
- Returning to an app is not evidence of a passed verification.
- No silent fallback from liveness to a selfie or native UI to hosted web.

## Platform Decision

image_picker, file_selector and url_launcher provide basic native capture,
selection and browser launching. These are not liveness providers. Confirm
provider-native requirements before implementing liveness. Add custom Swift/
Kotlin only when genuinely required. Simulator/APK builds do not establish
physical-device capture, permission or liveness compatibility.
