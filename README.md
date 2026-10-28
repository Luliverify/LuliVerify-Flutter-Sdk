# LuliVerify Flutter SDK

Integrate a business’s published LuliVerify workflow into a Flutter application
with one call. Choose SDK-owned native screens or open the hosted verification
website in the device’s browser.

LuliVerify supplies the workflow order, available steps, field labels, options,
validation rules, evidence requirements, and session state. The app supplies a
publishable key and **published release ID**; it does not rebuild the workflow.

## Contents

- [Requirements](#requirements)
- [Before you start](#before-you-start)
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
- [Further reading](#further-reading)

## Requirements

| Requirement | Current baseline |
| --- | --- |
| Flutter | 3.47.0 or newer |
| Dart | 3.13.0 or newer, below 4.0.0 |
| Android | API 24 or newer |
| iOS | 13.0 or newer |
| Host application | A mounted Flutter context below a Navigator |

The SDK targets Android and iOS. MaterialApp, CupertinoApp, or a suitably configured WidgetsApp can
provide the Navigator. The SDK installs its own theme and English Material
localizations on its route; your application theme is not replaced.

## Before you start

Have these values ready from your LuliVerify dashboard:

- A **publishable key** for your integration.
- The **release ID** of the published workflow you want to launch.
- For hosted mode, your registered HTTPS return URL and the App Link / Universal
  Link configuration for your application and domain.

The publishable key must permit that release. Use a release ID, not a workflow
or draft ID. A published release represents a specific workflow configuration;
when you choose a newly published version, update the release ID used by the app.

Use only the publishable key in your application. Keep private account credentials
and signing secrets out of the app and its configuration files.

## Install

For a local checkout:

```yaml
dependencies:
  flutter:
    sdk: flutter
  luliverify_flutter:
    path: ../luliverify-flutter-sdk
```

Or install from Git using your normal repository access:

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

Keep Git credentials outside `pubspec.yaml`. Use the Git or local-path installation
shown above.

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

Replace the placeholders with issued values. The SDK starts a LuliVerify session and displays the steps configured for your
published workflow.
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
| `widgetOrigin` | `https://verify.luliverify.io` | Expected HTTPS origin for LuliVerify hosted verification links. |
| `returnUrl` | Required for hosted; omit for native | Exact registered HTTPS app-return URL; no credentials or fragment. Query parameters participate in exact matching. |
| `httpClientFactory` | Optional | Advanced/testing hook. Return a **new** HTTP client on every call; the SDK owns and closes each client. |

The publishable key must use the issued `lv_pk_` format. Example placeholders are
not usable credentials. Configuration errors can throw before launching; failures
after the screen opens are presented by the SDK and reported via a sanitized
result when the screen closes. Do not rely on receiving an error result for every
programming error: for example, concurrent launches throw `StateError`.

Branding comes from your LuliVerify workflow settings, including `displayName`, supported
primary colour, button radius, action labels, and privacy/terms/support links.
Geist is bundled; Lucide outline icons and SDK-owned controls supply the default
appearance. Invalid/low-contrast accent colours fall back to the SDK
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

The SDK obtains a LuliVerify hosted verification link and opens the
`verify.luliverify.io` URL in the **external browser**. This is not an iframe or an
embedded WebView. The browser displays your configured verification flow.
A merchant does not need to host the verification widget on its own website.

### What “registered HTTPS app return URL” means

The return URL is the address the hosted site navigates to when returning to the
application. Two independent configurations are required:

1. **LuliVerify registration:** your integration permits that exact return URL.
2. **OS app/domain association:** Android/iOS knows that the HTTPS address belongs
   to your installed, signed application and can open it instead of a web page.

Typing an HTTPS URL into the example or registering it with LuliVerify does
**not** create an App Link or Universal Link. You need control of the return
address’s domain and its association files.

When a matching link reaches `app_links` while the SDK route is alive, the SDK
closes that route and resolves with `hostedReturned`. Other URLs are ignored.
The SDK does not append approval information to the URL or accept extra query
parameters added to it; matching uses the complete registered URI string.

### Return-link lifecycle

Configure the return address for your own signed application and domain. The SDK
listens for the exact registered link while its verification route is open.
Use the Android and iOS setup below to enable browser-to-app navigation.

If the application process is restarted, restore your app’s normal navigation and
retrieve the session result through your authorized LuliVerify integration. The
launch Future belongs to the original application process. A return link reports
navigation; it is not an approval decision.

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
uniform type identifiers corresponding to the workflow’s PDF/PNG/JPEG file policy.

Validate camera permissions, capture, file selection, and Universal Links on the
physical devices your application supports. The iOS simulator does not provide a
front-facing camera for selfie capture.

## Results, callbacks, and cancellation

`launch` returns `Future<LuliVerifyResult>`. Inspect `status` after awaiting it:

| `LuliVerifyResultStatus` | Meaning |
| --- | --- |
| `completed` | The native verification session completed. Retrieve the LuliVerify result before making an access decision. |
| `failed` | The native verification session ended with a failed status. |
| `cancelled` | LuliVerify confirmed that the session was cancelled. |
| `expired` | The native session reached its session expiry boundary. Start a new authorized launch. |
| `dismissed` | Local route was left without confirmed remote cancellation/completion, including hosted manual dismissal. |
| `hostedReturned` | A matching hosted return link was received while the route was active. Hosted verification outcome is not inferred. |
| `error` | A launch/link error was reported when the SDK route closed. See sanitized `errorCode`. |

`sessionId` and `errorCode` are nullable because the app can leave the flow before
a session is created or without an error. The API reference describes additional
session metadata available for advanced integrations.

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

- Native screens render the steps supplied by LuliVerify and supported field
  types: text, email, ISO date, number, and select. LuliVerify values are submitted
  unchanged; readable labels are display-only.
- Workflow configuration is managed in LuliVerify. For example, CAC lookup depth is
  an administrator setting, not an end-customer input.
- Upload slots, document types, MIME types, limits, required evidence, and recovery
  actions come from LuliVerify. Do not hardcode “front”/“selfie” roles or infer
  that storing a file means the document was verified.
- Upload feedback separates preparation, request-body transfer, and waiting for
  LuliVerify confirmation. Sending all bytes does not replace the final upload response.
- The selfie screen supports front-camera framing, review, and retake. Temporary
  camera files are cleaned up on a best-effort basis. Picker-owned upload buffers
  are copied so they can be cleared without modifying the caller’s buffer.
- LuliVerify resolves earlier document/selfie references for face comparison and
  enforces prerequisites/expiry. The customer does not choose arbitrary earlier
  asset IDs. Follow the returned recovery action when evidence expires.
- Follow the available actions and field requirements supplied by LuliVerify.
  The SDK keeps presentation and workflow progression aligned with that session.

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

For an existing authorized grant, use the low-level connection APIs only when
your integration needs custom orchestration. The normal publishable-key launch
requires no additional session-management code from your app.

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
| Cannot start / unauthorized / forbidden | Check the publishable key, enabled release, and release permission in your LuliVerify integration. |
| Empty or wrong workflow | Pass the published release ID, not a draft/workflow ID; publish and update the allowed release after changes. |
| Hosted launch rejected | Exact HTTPS return URL registered on the integration; native mode must omit it. |
| Return URL stays in browser | Configure/verify App Links or Universal Links on the app **and domain**; merely registering the URL is insufficient. |
| App opened but hosted Future did not resolve | Exact URI match, active SDK route, no duplicate deep-link handler. The launch Future belongs to the original application process. |
| `StateError` about an open flow | Await the previous launch; prevent duplicate taps. |
| Camera unavailable | Front camera available, OS permission granted, device supported. Use a physical device for capture checks. |
| File picker cannot show content on iOS | Check that the device’s Files provider can access the selected location. |
| Upload/step result uncertain | Refresh via the advanced controller before retrying; do not blindly replay mutations or consumed tickets. |
| Contract/field/status unsupported | Check SDK compatibility with the selected LuliVerify workflow. |

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
Include physical-device camera, file-selection, and verified return-link checks
in your application’s release validation.

## Further reading

- [Detailed integration guide](https://github.com/Luliverify/LuliVerify-Flutter-Sdk/blob/main/docs/INTEGRATION.md)
- [Example application](https://github.com/Luliverify/LuliVerify-Flutter-Sdk/blob/main/example/README.md)
- [Bundled Geist font licence](https://github.com/Luliverify/LuliVerify-Flutter-Sdk/blob/main/assets/fonts/OFL.txt)

Generate the API reference with `dart doc` for the complete class and method
contracts. IDE hover documentation is available through the public library import.
