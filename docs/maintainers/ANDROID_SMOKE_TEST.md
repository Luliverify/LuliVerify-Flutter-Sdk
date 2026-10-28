# Android development smoke test — 2026-10-28

Device: isolated LuliVerifySDKTest Android API 36.1 emulator, arm64.
API: deployed https://luli-api.luliverify.io, publishable-key native launch.
Existing account workflows were left unchanged. Dedicated test integration and
workflow were created; customer data and credentials are omitted here.

Passed on the actual emulator and deployed backend:
- Publishable-key launch and native one-use ticket exchange.
- Welcome submission and backend-defined upload slots/document types.
- Android file picker with a labelled synthetic PNG document.
- Native camera capture using the emulator scene, with no personal image.
- Clearly labelled dummy liveness, backend testOnly true.
- Face comparison reusing the earlier document and passed simulated liveness;
  no fresh uploads or client-picked source/target assets.
- Completion screen, return to host app, typed completed callback.
- Authenticated backend history confirmed all five steps passed in test mode.
- Existing CAC customer contract omitted detailLevel after backend deployment.
- Expired-session screen exercised; abandoned diagnostic session cancelled.

Bug found/fixed locally: Android file_selector returned an unmodifiable byte
buffer. Post-upload zeroing threw UnsupportedError despite successful upload.
Picked evidence now owns a mutable copy. Actual emulator upload passed after
the fix with no error banner; two regression tests cover read-only/caller-owned
buffers. All 59 Flutter tests and static analysis passed. Debug-only exception
diagnostics were removed from source and the installed final test build.

Not established by this smoke test: real biometric liveness or identity matching,
paid verification lookups, physical-device permissions/interruption matrix, or
hosted browser-to-app return (requires a registered, verified app link). No paid
identity lookup was performed. Results and callbacks do not grant real approval.


## Visual and camera pass — 28 October 2026

- Readable legacy-server titles and selector labels verified on Android; wire values remain unchanged.
- Synthetic document uploaded with visible preparation/upload/server confirmation states.
- Front-camera permission, dotted oval, capture, review, retake and accepted-photo upload verified with the emulator's synthetic scene.
- Comparison reused earlier document and test-liveness evidence; no paid identity calls or real personal documents.
- Camera lifecycle/denied access/front-camera requirement and rapid-retake cleanup covered by platform-fake tests.
- Welcome and expired layouts rendered at phone size; expired layout also checked at 320px with 1.6x text and in landscape.
- Camera guide provides framing only; liveness remains simulated in backend test mode (API metadata, not customer-facing copy). Physical-device/iOS checks are still required before release.

The dedicated emulator starts with `-camera-front emulated`; its saved AVD configuration has no front camera. Do not fall back silently to the back camera.
