# Mobile Contract Status

Inspected baseline: backend `4b1ec0a`. Native channel additions are local backend
changes accompanying this SDK milestone; they require deployment before use.

## Implemented Backend Contract

| Operation | Endpoint | Authentication |
| --- | --- | --- |
| Default native/hosted launch | POST /mobile/launches | Release-scoped publishable key; no Origin |
| Create native grant | POST /merchant/mobile-workflow-sessions | Private merchant key, server-only |
| Native resume grant | POST /merchant/mobile-workflow-sessions/:id/resume | Same integration key, resume enabled |
| Exchange grant | POST /mobile-sessions/:id/exchange | One-use ticket; no Origin |
| Read native session | GET /workflow-sessions/:id | X-Session-Token; no Origin |
| Submit step | POST /workflow-sessions/:id/steps | Same token; revision/idempotency envelope |
| Cancel | DELETE /workflow-sessions/:id | Same token; no request body |
| Upload | POST /workflow-sessions/:id/files | Same token; multipart metadata |
| Autosave | PATCH /workflow-sessions/:id/input | Same token; revision, stepId, input |
| Evidence recovery | POST /workflow-sessions/:id/evidence/recover | Same token; revision |

Native sessions are pinned to an accessChannel distinct from widget sessions.
Native requests reject any Origin header. Widget guards still enforce configured
origins and cannot consume native tickets. Never spoof browser Origin or embed
merchant keys in an app. Absence of Origin is not authentication; tickets/tokens
are the bearer credentials. Default mobile creation uses publishable keys with
the existing allowedReleaseIds permissions, rate limits and daily public quota.
Optional merchant grants can additionally bind an authenticated customer.

Grant lifetime is at most two minutes. Atomic exchange consumes it and rotates
the token. Pre-exchange idempotent creation retries replace the ticket; after
exchange, creation retries return 409. Resume preserves session expiry/position
and invalidates the prior token on exchange. Integration revocation and current
compliance are rechecked. Native widget handoff is unsupported (canHandoff false).

All current execution remains test-only. No app identifier, camera photo, client
callback or return link establishes final verification approval.

## Flutter Integration

Implemented: immutable contract parsing, revision-safe controller, no-redirect
HTTP adapter, in-memory tokens, abortable requests, native scalar forms, consent,
file/camera picker, multipart evidence upload, basic session presentation and
explicit hosted-browser launch with host-routed app-return validation.

The single-call LuliVerify.launch API now owns navigation and session resources,
uses publishable-key creation and provides native/hosted modes. Hosted app_links
handling requires OS domain association by the host. The custom native surface
uses #1F3FE2, Geist and Lucide icons; no merchant-owned server is needed to launch.

The HTTP adapter owns its injected client. Tokens are removed from observable
snapshots. Errors never display raw provider responses. Network operations do
not retry automatically. Disposal aborts local requests; remote cancellation is
an explicit operation. Ambiguous exchange requires a fresh merchant-authorized
grant rather than ticket replay.

## Remaining Release Gates

- Deploy matching backend additions before testing real native launches.
- Provider-native liveness and OTP delivery remain unintegrated. Production
  liveness blocks; backend-marked test sessions have a dummy
  path that uploads a selfie and uses a synthetic scenario. A photo does not
  establish human presence, and authored workflow test outcomes are preserved.
  Test flags remain in session/result metadata; customer screens omit test notices.
- Configure OS-verified universal/app links in each merchant app. The hosted
  adapter validates an exact registered return URL but does not own app routing.
- Each merchant must authenticate its app user before issuing/resuming a grant
  and confirm final results through its backend or signed webhooks.
- Verify camera/file permissions, Android activity loss, background/resume,
  expired evidence and accessibility on physical Android/iOS devices.
- A passed simulator compile is not a physical-device capture/liveness test.
- Confirm distribution license, app privacy disclosures and compatibility matrix.

React Native remains a scaffold and is not modified by this implementation.
