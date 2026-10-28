# Flutter integration guide

Use the Flutter SDK to launch a published LuliVerify workflow with native screens
or the hosted verification website. LuliVerify supplies the steps, fields,
options, validation requirements, and session progression.

## Credentials and workflow selection

Obtain a publishable key and published release ID from your LuliVerify dashboard.
The integration must permit the selected release. Use a release ID rather than a
workflow or draft ID. Update the app’s release ID when choosing a newly published
workflow version.

Only publishable credentials belong in the app. Keep private account credentials,
launch tickets, and session tokens out of source control and logs.

## Native integration

```dart
import 'package:flutter/widgets.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

Future<LuliVerifyResult> startVerification(BuildContext context) {
  return LuliVerify.launch(
    context,
    publishableKey: 'YOUR_PUBLISHABLE_KEY',
    releaseId: 'YOUR_PUBLISHED_RELEASE_ID',
    customerReference: 'optional-customer-reference',
  );
}
```

Replace the placeholders with issued values. The SDK owns its route, session,
forms, evidence capture, uploads, and resource cleanup. The context must be
mounted below a Navigator supplied by MaterialApp, CupertinoApp, or WidgetsApp.
No additional verification screen or navigation boilerplate is required.

One verification flow may be open at a time. Disable repeated launch actions while
awaiting the result, and check `context.mounted` before changing host UI afterwards.
Native mode does not use a return URL.

## Configuration

The launch API accepts `publishableKey`, `releaseId`, `customerReference`, `mode`,
`returnUrl`, `apiBaseUrl`, `widgetOrigin`, and `httpClientFactory`. The
[README configuration table](../README.md#launch-configuration) describes defaults
and constraints. A customer reference is correlation metadata, not authentication.

The SDK applies workflow branding in its own route without replacing the host
application’s theme. Customer-facing labels and options follow the LuliVerify
session. SDK-owned copy is English.

Advanced integrations can provide `httpClientFactory`. Return a fresh client on
each invocation; the SDK owns and closes it. Do not inject private credentials,
cookies, Origin headers, or automatic mutation retries.

## Hosted integration

```dart
import 'package:flutter/widgets.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

Future<LuliVerifyResult> startHostedVerification(BuildContext context) {
  return LuliVerify.launch(
    context,
    publishableKey: 'YOUR_PUBLISHABLE_KEY',
    releaseId: 'YOUR_PUBLISHED_RELEASE_ID',
    mode: LuliVerifyPresentation.hostedWeb,
    returnUrl: Uri.parse('https://app.your-domain.example/verification-return'),
  );
}
```

Hosted mode opens the LuliVerify website in the external browser. Your application
does not need an iframe, embedded WebView, or website to host the widget.

### Configure the return link

Use an HTTPS address on a domain you control. Register its exact URL in your
LuliVerify integration, then associate the address with your installed app:

- **Android:** add a verified VIEW intent filter and publish
  `.well-known/assetlinks.json` for the actual package/signing identity.
- **iOS:** enable Associated Domains with `applinks:your-domain` and publish
  `apple-app-site-association` for the actual Apple team/bundle identity and paths.

The example’s return-URL field provides launch configuration. Configure the
platform and domain associations for your own app before using that field.
Registration with LuliVerify and OS domain verification are separate requirements.
See the [Android](../README.md#android-setup) and [iOS](../README.md#ios-setup)
configuration examples and the app_links platform setup instructions.

### Handle the return

The SDK listens for an exact matching URI while its route remains open. Matching
includes the full registered URL and query string. Repeated or unrelated links
are ignored. An accepted return closes the SDK route and resolves its Future
with `LuliVerifyResultStatus.hostedReturned`.

The Future belongs to the application process that started it. If your app is
restarted, restore its normal navigation and retrieve the session result through
your authorized LuliVerify integration. A return link reports navigation; use the
LuliVerify result when making application access decisions.

## Results and closing

The result includes a status, optional session ID, and optional sanitized error
code. See the [result table](../README.md#results-callbacks-and-cancellation).

- Native results reflect the session’s completed, failed, cancelled, or expired
  status.
- `hostedReturned` reports receipt of the registered return link.
- `dismissed` indicates local closure without confirmed remote cancellation.
- `error` indicates a launch/link error reported when the route closes.

Leaving a native session asks for confirmation and requests cancellation when the
session is ready. The returned state distinguishes confirmed cancellation from
local dismissal. Leaving the hosted SDK screen does not cancel the browser session.

Treat callbacks as navigation/session notifications. Retrieve the verification
result from LuliVerify before granting sensitive access in your application.

## Evidence, forms, and permissions

LuliVerify supplies field definitions, upload roles, accepted file types, limits,
and available recovery actions. The SDK supports PDF/PNG/JPEG selection according
to the session requirements and a guided front-camera view with review/retake.
Camera capture records no audio.

The SDK handles evidence references between workflow steps. Follow the available
recovery action when evidence must be recaptured. Selection labels are for display;
original field/option values are submitted unchanged.

Upload feedback separates preparing media, transmitting it, and awaiting
LuliVerify confirmation. Completion of byte transfer is not the final upload
response. The SDK clears owned upload buffers after use and cleans temporary
camera files on a best-effort basis.

Android requires INTERNET permission and API 24+. iOS requires 13.0+ and camera/
photo-library usage descriptions. Refer to the platform sections in the README
for the exact configuration. Include camera, file selection, permissions,
interruption/recovery, and verified return links in physical-device validation.

## Advanced lifecycle APIs

Prefer `LuliVerify.launch` for normal integration. For a custom presenter:

- A session controller owns one session transport and disposes it with the controller.
- A session screen displays a supplied controller but does not dispose host-owned
  controllers itself.
- Coordinate evidence/autosave operations with other session mutations, then refresh
  the controller before the next submission.
- Refresh after an uncertain mutation rather than blindly replaying it.
- A low-level hosted launcher checks forwarded links; it does not install OS
  domain associations or listen for links on its own.
- Recovered Android picker media must be reconfirmed for the current session and
  role before attachment.

The Dart API comments document parameters, return values, ownership, and failure
behaviour for each public class/method. Generate the reference with `dart doc`.
