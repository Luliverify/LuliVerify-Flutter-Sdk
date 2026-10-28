# Changelog

## 0.1.0-dev.1

- Private SDK foundation, configuration tests and Android/iOS example hosts.
- Verification execution and native capture are not implemented.

## Unreleased

- Normalize backend display labels without changing submitted values.
- Redesign welcome and terminal screens, add Powered by LuliVerify branding.
- Show preparation, streamed upload progress and server-confirmation status.
- Add front-camera selfie framing with a dotted guide, review and retake.
- Release camera resources on interruption and recover on return; preserve
  backend test-only metadata. The guide is not a face detector.

- Own a mutable evidence buffer before cleanup; Android picker buffers may be
  read-only and must not turn a successful upload into an error banner.

- Add one-call publishable-key native/hosted launching with SDK-owned navigation.
- Add custom brand controls, Geist font and Lucide outline icons.
- Register validated app-return handling during hosted sessions.

- Parse v1 session/input contracts from backend-generated sanitized fixtures.
- Preserve immutable field/options/upload metadata; strip session tokens.
- Add revision-safe session orchestration behind an injectable transport.
- Guard expiry, concurrent requests, ambiguous outcomes and late responses.
- Add server-grant native authentication and no-redirect HTTP/multipart transport.
- Add backend-driven forms, native session view, capture and file selection.
- Add explicit hosted browser launch and exact app-return matching.
- Add native grant support and a publishable-key example; configure permissions.
- Liveness/OTP provider integration and physical-device validation remain gates.

- Remove customer-visible test/simulation copy; retain test flags and production guards.
- Use an inline close control on the selfie screen without a separate app bar.

- Fix iOS document selection with server-derived uniform type identifiers; retain matching Android extension/MIME filters.
