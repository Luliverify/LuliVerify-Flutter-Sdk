# LuliVerify Flutter SDK

Integrate a business’s published LuliVerify workflow into a Flutter application
with one call. Choose SDK-owned native screens or open the hosted verification
website in the device’s browser.

The backend supplies the workflow order, available steps, field labels, options,
validation rules, evidence requirements, and session state. The app supplies a
publishable key and **published release ID**; it does not rebuild the workflow.

> **Development status:** this package is private and not published on pub.dev.
> Current backend verification execution is test-only. Real provider-native
> liveness and OTP delivery are not integrated. Customer screens omit test notices;
> `testOnly` remains available in API/result metadata. A camera photo or a callback
> must not be treated as proof of identity or final approval.

## Contents

- [Requirements](#requirements)
- [Business and backend setup](#business-and-backend-setup)
- [Install](#install)
- [Native quick start](#native-quick-start)
- [Launch configuration](#launch-configuration)
- [Hosted browser flow](#hosted-browser-flow)
- [Android setup](#android-setup)
- [iOS setup](#ios-setup)
- [Results, callbacks, and cancellation](#results-callbacks-and-cancellation)
- [Workflow behaviour and evidence](#workflow-behaviour-and-evidence)
- [Advanced APIs and resource ownership](#advanced-apis-and-resource-ownership)
- [Example application](#example-application)
- [Troubleshooting](#troubleshooting)
- [Development and API documentation](#development-and-api-documentation)
- [Architecture and further reading](#architecture-and-further-reading)

## Requirements

| Requirement | Current baseline |
| --- | --- |
| Flutter | 3.47.0 or newer |
| Dart | 3.13.0 or newer, below 4.0.0 |
| Android | API 24 or newer |
| iOS | 13.0 or newer |
| Backend | Compatible mobile launch, session, and input-contract version 1 endpoints |
| Host application | A mounted Flutter context below a Navigator |

Android and iOS are the intended mobile targets. Other platforms are not validated
SDK targets. MaterialApp, CupertinoApp, or a suitably configured WidgetsApp can
provide the Navigator. The SDK installs its own theme and English Material
localizations on its route; your application theme is not replaced.

## Business and backend setup

1. Complete the business’s onboarding/compliance requirements in LuliVerify.
2. Create a workflow, configure its tools/settings, and **publish** it.
3. Obtain that published **release ID**. A workflow/draft ID is not a release ID.
4. Issue a publishable key for the account’s integration and allow the release in
   its `allowedReleaseIds` configuration.
5. For hosted mode, also register the exact HTTPS return URL and configure its
   Android App Link / iOS Universal Link association.

Each launch uses the published release’s snapshot. Editing a draft does not change
an existing release or session. After publishing a replacement, supply the new
release ID and ensure the integration permits it. The SDK never selects the
“latest” workflow implicitly.

A business-owned server is **not required to start** the publishable-key flow.
Private merchant keys, dashboard passwords, JWTs, and webhook secrets must stay
off the device. A trusted server/dashboard is still the place to check
merchant-authoritative verification outcomes and make access decisions.

## Install

For a local checkout:

```yaml
dependencies:
  flutter:
    sdk: flutter
  luliverify_flutter:
    path: ../luliverify-flutter-sdk
```

Or use the private Git repository with your normal Git access configured:

```yaml
dependencies:
  luliverify_flutter:
    git:
      url: https://github.com/Luliverify/LuliVerify-Flutter-Sdk.git
      ref: main # Prefer a reviewed full commit SHA for a reproducible integration.
```

```sh
flutter pub get
```

Do not put Git credentials in `pubspec.yaml`. There is currently no supported
`flutter pub add luliverify_flutter` installation from pub.dev.

## Native quick start

Call from a button or another user action with a mounted context. No SDK route,
controller, Material screen, or navigation boilerplate is required from the app.

```dart
import 'package:flutter/widgets.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

Future<LuliVerifyResult> verifyCustomer(BuildContext context) {
  return LuliVerify.launch(
    context,
    publishableKey: 'YOUR_PUBLISHABLE_KEY',
    releaseId: 'YOUR_PUBLISHED_RELEASE_ID',
    customerReference: 'your-customer-reference', // Optional correlation value.
  );
}
```

Replace the placeholders with issued values. The SDK creates a session, exchanges
its short-lived one-use native ticket, and renders the backend’s available steps.
It handles fields, consent, file selection, capture, uploads, progression, and
cleanup. The returned Future resolves when the SDK route closes, rather than at
the instant the last form is submitted.

Only one SDK launch can be open in a Dart isolate at a time. Disable your launch
button while awaiting the result and check `context.mounted` before updating your
own UI afterwards. Native mode does not use a return URL.

## Launch configuration

`LuliVerify.launch(context, ...)` accepts:

| Argument | Required/default | Meaning |
| --- | --- | --- |
| `publishableKey` | Required | Issued `lv_pk_…` creation-only key; must allow the release. Never a private merchant key. |
| `releaseId` | Required | Published release ID, a 24-character lowercase hexadecimal identifier. |
| `mode` | `LuliVerifyPresentation.nativeUi` | Native screens or `LuliVerifyPresentation.hostedWeb`. No automatic fallback. |
| `customerReference` | Optional | 1–150 characters when supplied. Correlation only; not authentication or an authorization claim. |
| `apiBaseUrl` | `https://luli-api.luliverify.io` | Compatible HTTPS API base; no credentials, query, or fragment. |
| `widgetOrigin` | `https://verify.luliverify.io` | Expected HTTPS origin for backend-minted hosted URLs; does not bypass browser/backend origin guards. |
| `returnUrl` | Required for hosted; omit for native | Exact registered HTTPS app-return URL; no credentials or fragment. Query parameters participate in exact matching. |
| `httpClientFactory` | Optional | Advanced/testing hook. Return a **new** HTTP client on every call; the SDK owns and closes each client. |

The publishable key must use the issued `lv_pk_` format. Example placeholders are
not usable credentials. Configuration errors can throw before launching; failures
after the screen opens are presented by the SDK and reported via a sanitized
result when the screen closes. Do not rely on receiving an error result for every
programming error: for example, concurrent launches throw `StateError`.

Branding comes from backend session metadata, including `displayName`, supported
primary colour, button radius, action labels, and privacy/terms/support links.
Geist is bundled; Lucide outline icons and SDK-owned controls supply the default
appearance. Invalid/low-contrast backend accent colours fall back to the SDK
colour. The main launch API has no independent theme or locale argument; current
SDK-owned UI copy is English.

## Hosted browser flow

```dart
import 'package:flutter/widgets.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

Future<LuliVerifyResult> verifyInBrowser(BuildContext context) {
  return LuliVerify.launch(
    context,
    publishableKey: 'YOUR_PUBLISHABLE_KEY',
    releaseId: 'YOUR_PUBLISHED_RELEASE_ID',
    mode: LuliVerifyPresentation.hostedWeb,
    returnUrl: Uri.parse('https://app.your-domain.example/verification-return'),
  );
}
```

The SDK requests a hosted mobile launch from the backend and opens the returned
`verify.luliverify.io` URL in the **external browser**. This is not an iframe or an
embedded WebView. The browser exchanges its own ticket and runs the hosted UI.
A merchant does not need to host the verification widget on its own website.

### What “registered HTTPS app return URL” means

The return URL is the address the hosted site navigates to when returning to the
application. Two independent configurations are required:

1. **Backend allowlist:** the integration permits that exact return URL.
2. **OS app/domain association:** Android/iOS knows that the HTTPS address belongs
   to your installed, signed application and can open it instead of a web page.

Typing an HTTPS URL into the example or adding it to the backend allowlist does
**not** create an App Link or Universal Link. You need control of the return
address’s domain and its association files. The temporary owned-domain URL used
for the hosted launch smoke test was not a configured app link.

When a matching link reaches `app_links` while the SDK route is alive, the SDK
closes that route and resolves with `hostedReturned`. Other URLs are ignored.
The SDK does not append approval information to the URL or accept extra query
parameters added to it; matching uses the complete registered URI string.

### Current return limitations

- The checked-in example has **no Android App Link intent filter or iOS Associated
  Domains entitlement** configured. Its hosted launch has been checked, but a
  real website-to-app return has not been verified end to end.
- The callback event-listener test verifies exact matching, wrong-link rejection,
  and returning control to the app. It does not prove OS domain association.
- If the OS kills the application while the browser is open, this SDK does not
  restore its memory-only flow on cold start. Restore the app’s own navigation and
  retrieve outcomes through an authorized server/dashboard.
- The operating system, browser, domain association, and user link preferences
  affect whether a link opens the app. A return is navigation, not approval.

## Android setup

Use Android API 24 or newer and add INTERNET permission to the host application:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Camera plugins request permission when capture is used. File selection does not
require broad storage access. The SDK’s selfie screen uses the front camera with
no audio recording. The framing guide is not face detection or provider liveness.

For hosted returns, add a verified VIEW intent filter to your Flutter activity.
This is a **template**, not an already configured domain:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="https"
        android:host="app.your-domain.example"
        android:pathPrefix="/verification-return" />
</intent-filter>
```

Serve `https://app.your-domain.example/.well-known/assetlinks.json` with your real
Android application ID and signing certificate SHA-256 fingerprints. Development
and store signing identities may differ. Configure Flutter’s default deep-link
handling consistently with `app_links` so the same link is not consumed twice.
For the dependency’s platform instructions, see the
[app_links Android guide](https://github.com/llfbandit/app_links/blob/main/doc/README_android.md).

Validate domain verification on the installed app/device as well as the SDK
callback. A forced Android intent is not proof that browser links are verified.

## iOS setup

Use an iOS deployment target of 13.0 or newer. Add usage descriptions in the
application’s `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Capture documents and photos for verification.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Select documents and photos for verification.</string>
```

For hosted returns, enable Associated Domains on the app’s signed target and
include `applinks:app.your-domain.example`. Serve the Apple
`apple-app-site-association` file on that domain with the real Apple team ID,
bundle ID, and allowed return paths. The SDK cannot provide these merchant-owned
identities or publish the association file for you. Follow the
[app_links iOS guide](https://github.com/llfbandit/app_links/blob/main/doc/README_ios.md)
for its setup and interaction with Flutter’s default deep-link handler.

The SDK records no microphone audio. iOS document selection includes native
uniform type identifiers corresponding to the backend’s PDF/PNG/JPEG policy.

An iOS simulator build and UI check have passed. The simulator has no front
camera, and its Files browser returned “Content Unavailable” during testing.
Actual iPhone capture, permission prompts, upload, retake, interruption/recovery,
and verified Universal Link return still require device validation. See the
[iOS smoke-test report](https://github.com/Luliverify/LuliVerify-Flutter-Sdk/blob/main/docs/IOS_SMOKE_TEST.md) for the exact scope.

## Results, callbacks, and cancellation

`launch` returns `Future<LuliVerifyResult>`. Inspect `status` after awaiting it:

| `LuliVerifyResultStatus` | Meaning |
| --- | --- |
| `completed` | Backend native session reached completed. This does not itself authorize a customer or prove a provider check passed. |
| `failed` | Backend native session reached failed. |
| `cancelled` | Backend native session cancellation was confirmed. |
| `expired` | The native session reached its backend/local expiry boundary. Start a new authorized launch. |
| `dismissed` | Local route was left without confirmed remote cancellation/completion, including hosted manual dismissal. |
| `hostedReturned` | A matching hosted return link was received while the route was active. Hosted verification outcome is not inferred. |
| `error` | A launch/link error was reported when the SDK route closed. See sanitized `errorCode`. |

`sessionId`, `testOnly`, and `errorCode` are nullable because a failure/dismissal
can happen before a session is created. Test flags stay in metadata even though
the customer UI does not display simulation notices.

```dart
import 'package:luliverify_flutter/luliverify_flutter.dart';

String resultMessage(LuliVerifyResult result) {
  return switch (result.status) {
    LuliVerifyResultStatus.completed => 'Information submitted.',
    LuliVerifyResultStatus.hostedReturned => 'Returned from the browser.',
    LuliVerifyResultStatus.cancelled => 'Verification cancelled.',
    LuliVerifyResultStatus.expired => 'Start a new verification session.',
    LuliVerifyResultStatus.failed => 'Verification could not be completed.',
    LuliVerifyResultStatus.dismissed => 'Verification closed.',
    LuliVerifyResultStatus.error => 'Unable to finish verification.',
  };
}
```

Native leaving asks for confirmation and attempts remote cancellation when the
controller is ready. If that cannot be confirmed, the result is dismissed or an
error rather than a fabricated cancellation. Leaving the hosted SDK screen does
not cancel the browser’s remote session. Tokens and tickets are memory-only.

Do not automatically retry ambiguous launch/ticket exchanges or step submissions.
A ticket may already have been consumed or a mutation accepted. Advanced users
should refresh after an uncertain mutation. A new call to `launch` creates a new
launch attempt; it is not resume-by-session-ID.

## Workflow behaviour and evidence

- Native screens render the backend’s current/available steps and supported field
  types: text, email, ISO date, number, and select. Server values are submitted
  unchanged; readable labels are display-only.
- Workflow configuration remains backend-owned. For example, CAC lookup depth is
  an administrator setting, not an end-customer input.
- Upload slots, document types, MIME types, limits, required evidence, and recovery
  actions come from the backend. Do not hardcode “front”/“selfie” roles or infer
  that storing a file means the document was verified.
- Upload feedback separates preparation, request-body transfer, and waiting for
  server confirmation. Sending all bytes does not prove the server accepted them.
- The selfie screen supports front-camera framing, review, and retake. Temporary
  camera files are cleaned up on a best-effort basis. Picker-owned upload buffers
  are copied so they can be cleared without modifying the caller’s buffer.
- The backend resolves earlier document/selfie references for face comparison and
  enforces prerequisites/expiry. The customer does not choose arbitrary earlier
  asset IDs. Follow the returned recovery action when evidence expires.
- Unsupported contracts, provider-only steps, or developer test-runner inputs are
  blocked explicitly. There is no silent native-to-hosted or liveness-to-photo
  production fallback.

## Advanced APIs and resource ownership

Most integrations should use `LuliVerify.launch`. Lower-level APIs are exported
for apps that need their own orchestration and have reviewed the lifecycle rules:

| API | Responsibility |
| --- | --- |
| `LuliVerifyConfig` | Validated API base and native/hosted selection. |
| `LuliVerifyNativeSessionTransport.createLaunch` | Create a public-key mobile launch; owns/closes its supplied HTTP client, even on error. Returns sensitive one-use grant data. |
| `LuliVerifyNativeGrant.fromJson` | Parse native grant **data**, not an API envelope. Grant is consumed once, including ambiguous exchange failure. |
| `LuliVerifyNativeSessionTransport.connect` | Exchange a native grant and own its in-memory token/client. `initialSession` returns the latest accepted transport snapshot (initially the exchange response). |
| `LuliVerifySessionController` | Own one session and transport; observable phases, revision checks, expiry and serialized mutations. |
| `LuliVerifySessionScreen` | Native presenter; the host still owns/disposes the supplied controller. Controller and transport must identify the same session. |
| `LuliVerifyContractForm` | Render scalar fields only. The host supplies evidence and consent through the session flow. |
| `LuliVerifyHostedLaunch` | Validate/open a hosted URL once and check forwarded return URIs. Does not itself register OS app links or listen for them. |
| `LuliVerifyEvidencePicker` | Select/capture permitted files. Selection/capture is not verification. |

When the controller owns a transport, disposing the controller disposes that
transport. Disposing the session screen alone does **not** dispose a host-owned
controller. Disposing a controller/transport does not silently cancel the remote
session. Avoid sharing either across customers or overlapping requests.

Transport helpers include `read`, `submit`, `cancel`, `upload`, `removeFile`,
`recoverEvidence`, and `saveInput`. Evidence/autosave operations must be serialized
with controller operations and followed by `controller.refresh()` before the next
mutation. Do not treat the transport’s latest snapshot as an automatically adopted
controller revision. Never send cookies, a browser Origin, dashboard JWTs, or
private merchant keys through a native transport.

Server-created native sessions and authorized resume grants remain optional
advanced flows. They require a trusted merchant server to issue the grant; the
normal publishable-key launch does not. There is intentionally no public-key plus
session-ID API for recovering access to an existing session.

## Example application

From the repository root:

```sh
flutter pub get
cd example
flutter pub get
flutter run
```

Enter a publishable key and permitted release ID on the example screen. Select
“Use hosted browser flow” only after configuring its registered return URL and
OS/domain associations. Native mode needs no callback URL.

The example supports these compile-time development settings:

| Dart define | Use |
| --- | --- |
| `PUBLISHABLE_KEY` | Prepopulate the publishable-key field. |
| `RELEASE_ID` | Prepopulate the published release field. |
| `API_BASE_URL` | Override the default API domain with compatible HTTPS. |
| `RETURN_URL` | Prepopulate the hosted return field; does not configure OS links. |

```sh
flutter run --dart-define-from-file=/absolute/path/to/local-sdk-config.json
```

Example local configuration (all values are placeholders):

```json
{
  "PUBLISHABLE_KEY": "YOUR_PUBLISHABLE_KEY",
  "RELEASE_ID": "YOUR_PUBLISHED_RELEASE_ID",
  "API_BASE_URL": "https://luli-api.luliverify.io",
  "RETURN_URL": "https://app.your-domain.example/verification-return"
}
```

Dart defines are compiled into the app; they are **not secret storage**. Only use
public configuration here. Never include a merchant key, password, session token,
or launch ticket, and do not commit a real account’s local configuration file.
The example starts in native mode; the switch selects hosted mode.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Cannot start / unauthorized / forbidden | Correct publishable key, approved account, enabled release, and that release in the integration allowlist. |
| Empty or wrong workflow | Pass the published release ID, not a draft/workflow ID; publish and update the allowed release after changes. |
| Hosted launch rejected | Exact HTTPS return URL registered on the integration; native mode must omit it. |
| Return URL stays in browser | Configure/verify App Links or Universal Links on the app **and domain**; merely registering the URL is insufficient. |
| App opened but hosted Future did not resolve | Exact URI match, active SDK route, no duplicate deep-link handler. Cold-start restoration is not implemented. |
| `StateError` about an open flow | Await the previous launch; prevent duplicate taps. |
| Camera unavailable | Front camera available, OS permission granted, device supported. Simulators do not prove physical capture support. |
| File picker cannot show content on iOS | Check the native Files provider/device; see the smoke report. UTI filters are supplied by the SDK. |
| Upload/step result uncertain | Refresh via the advanced controller before retrying; do not blindly replay mutations or consumed tickets. |
| Contract/field/status unsupported | Update the SDK/backend together; do not guess or silently skip required checks. |

Errors are sanitized. Do not add tokens, evidence bytes, private credentials, or
provider payloads to logs, crash reports, or analytics when investigating them.

## Development and API documentation

From the package root:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test example/lib example/test
flutter analyze
flutter test
cd example
flutter pub get
flutter analyze
flutter test
```

Public classes, constructors, parameters, properties, and methods have Dart `///`
API documentation for IDE hover help. Import the public entry point rather than
`lib/src` internals. Generate browsable API documentation from the package root:

```sh
dart doc --output=doc/api
```

Generated API files are ignored by Git. Keep the README, integration guide,
example, API comments, and behaviour aligned when changing public contracts.
Widget/unit tests do not prove physical-device camera permissions, actual provider
liveness, verified domain associations, or production readiness.

## Architecture and further reading

```text
lib/luliverify_flutter.dart   Public API exports
lib/src/core/                Configuration, parsers, errors, HTTP transport
lib/src/features/session/    Observable session orchestration and lifecycle
lib/src/presentation/        Native controls/screens and hosted browser adapter
lib/src/platform/            File/camera adapters
example/                    Android/iOS integration example
test/                       Contracts, transport, lifecycle, UI and callback tests
docs/                       Integration details, architecture and validation scope
```

- [Detailed integration guide](https://github.com/Luliverify/LuliVerify-Flutter-Sdk/blob/main/docs/INTEGRATION.md)
- [Architecture](https://github.com/Luliverify/LuliVerify-Flutter-Sdk/blob/main/docs/ARCHITECTURE.md)
- [Mobile contract audit](https://github.com/Luliverify/LuliVerify-Flutter-Sdk/blob/main/docs/MOBILE_CONTRACT_AUDIT.md)
- [Android smoke test](https://github.com/Luliverify/LuliVerify-Flutter-Sdk/blob/main/docs/ANDROID_SMOKE_TEST.md)
- [iOS smoke test and known limits](https://github.com/Luliverify/LuliVerify-Flutter-Sdk/blob/main/docs/IOS_SMOKE_TEST.md)
- [Roadmap](https://github.com/Luliverify/LuliVerify-Flutter-Sdk/blob/main/docs/ROADMAP.md)
- [Example README](https://github.com/Luliverify/LuliVerify-Flutter-Sdk/blob/main/example/README.md)
- [Bundled Geist font licence](https://github.com/Luliverify/LuliVerify-Flutter-Sdk/blob/main/assets/fonts/OFL.txt)

This repository is a private development package (`publish_to: none`). Its current
identifiers and release process should be reviewed before a public distribution.
