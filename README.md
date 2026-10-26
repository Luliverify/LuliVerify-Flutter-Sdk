# LuliVerify Flutter SDK

Private foundation, not a working verification SDK. Flutter is the first implementation.

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

Only configuration and local errors are implemented. Other modules contain
ownership notes, not fake clients/provider responses. Compose maintained plugins
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

The example displays presentation intent only. No HTTP calls, capture, liveness,
redirect or verification is implemented. Native device builds remain unverified.
Package names/identifiers are provisional and publication is disabled.
See [architecture](docs/ARCHITECTURE.md) and [roadmap](docs/ROADMAP.md).
