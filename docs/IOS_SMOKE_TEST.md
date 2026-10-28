# iOS simulator smoke test — 28 October 2026

Environment: Xcode 26.6, iPhone 17 Pro Max simulator, iOS 26.5.

Verified:
- Debug simulator build, install and launch succeed.
- Publishable-key launch reaches the deployed API and opens Welcome.
- Continue advances to Document upload; side/type sheets show readable labels.
- Customer screens omit SDK-generated test/simulation notices.
- Selfie screen uses a white surface and inline close control, with no app bar.
- Missing front camera shows a recovery message and keeps capture disabled.
- Closing the selfie view returns to the existing document step.

Found and fixed: file_selector on iOS rejects extension-only type filters. The
picker now receives uniform type identifiers derived from the backend MIME
policy (PDF, PNG, JPEG), with matching extension/MIME filters for other platforms.
Two regression tests cover document and selfie file-type policies. All 71 SDK
tests and analysis pass.

After the fix the native Files picker opens. This simulator's Files browser then
returns “Content Unavailable”; a successful file selection/upload was not verified
on iOS. Retest with a working Files provider on a device or another simulator.
The simulator has no front camera, so actual camera capture, permission prompts,
retake and lifecycle behaviour still require a physical iPhone. Android's synthetic
capture/upload/comparison smoke test is documented separately.

No real identity documents or paid identity lookups were used. The matching
backend presentation release was validated separately without paused extraction
work: 356 tests passed, 24 database integration tests skipped, contract audit clean.
