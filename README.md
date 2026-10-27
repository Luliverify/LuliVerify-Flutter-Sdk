# LuliVerify Flutter SDK

Development SDK for backend-driven native and hosted sessions. Execution remains
test-only; provider-native liveness and production readiness are separate gates.

## Quick start

```dart
final result = await LuliVerify.launch(
  context,
  publishableKey: 'lv_pk_...',
  releaseId: 'YOUR_PUBLISHED_RELEASE_ID',
);
```

The SDK owns navigation, creation/exchange, controllers, fields, evidence and
cleanup. Your app needs a Flutter Navigator (MaterialApp, CupertinoApp or
WidgetsApp); you do not create SDK screens or Material routes yourself.
The publishable key must permit that release using the integration's existing
allowedReleaseIds setting. No merchant server is needed to launch. Never embed
a private merchant key. Client customer references are correlation only.

Optional arguments: `customerReference`, `mode`, `returnUrl`, `apiBaseUrl`, and
`widgetOrigin`. Hosted mode requires a registered HTTPS app link and platform
domain associations. See the integration guide for setup and result semantics.
Native callbacks describe session status; hosted returns describe navigation.
Neither is authorization to grant sensitive access.

```text
lib/luliverify_flutter.dart       Public exports only
lib/src/core/config/             Non-secret SDK configuration
lib/src/core/errors/             SDK-local errors
lib/src/core/contracts/          Backend parsers and sanitized fixtures
lib/src/core/network/            HTTP, cancellation and retry boundaries
lib/src/features/session/        Exchange, revisions and lifecycle
lib/src/features/evidence/       Upload roles, reuse, expiry and recovery
lib/src/presentation/native/     Backend-driven Flutter screens
lib/src/presentation/hosted/     Browser launch and validated app return
lib/src/platform/               Device adapters
test/                           Package tests
example/                        Android/iOS host with local path dependency
docs/                           Architecture and delivery checklist
```

Configuration, immutable backend contracts, a revision-safe controller, native
HTTP transport, backend-driven scalar forms, native capture/file selection and
multipart uploads are implemented. A hosted browser adapter is separate. There
are no fabricated provider results. Compose maintained plugins
before adding Swift/Kotlin code; no custom platform bridge is justified yet.

## Develop

Baseline: Flutter 3.47 / Dart 3.13, the installed toolchain at setup. Older versions
have not been validated. From this repository:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test example/lib example/test
flutter analyze
flutter test
cd example
flutter pub get
flutter test
flutter run
```

The example accepts a publishable key and release ID and invokes the single-call
launcher. Matching backend additions must be deployed first. Real-provider
liveness and OTP delivery are not implemented. Liveness has an explicitly labeled
test-only simulation; production liveness remains blocked.
Package names/identifiers are provisional and publication is disabled.
See [architecture](docs/ARCHITECTURE.md) and [roadmap](docs/ROADMAP.md).

## Session Core

`LuliVerifySession.fromResponse` parses backend envelopes and rejects unknown
versions, unsupported field/status types and inconsistent step contracts.
Field/options, evidence and upload metadata remain deeply immutable.
Session tokens are stripped from public snapshots.

`LuliVerifySessionController` owns one injected `LuliVerifySessionTransport`,
exposes observable state, serializes mutations, rejects stale/wrong-session
responses, and blocks expired/backend-disabled submission. Failed or ambiguous
mutations are not retried; refresh first. Disposing invalidates late responses
and releases local resources, without silently cancelling the remote session.

Terminal notifications are advisory, not merchant-authoritative approval. Steps
requiring developer test outcomes are blocked, not exposed as customer outcome
selectors. See the [integration guide](docs/INTEGRATION.md) and
[mobile contract status](docs/MOBILE_CONTRACT_AUDIT.md).
