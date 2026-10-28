# LuliVerify Flutter example

A development host for `LuliVerify.launch`, using the package via a local path
dependency. It demonstrates SDK-owned routing in native and hosted modes; it does
not implement its own verification UI or bundle private credentials.

## Before running

- Use Flutter 3.47+/Dart 3.13+ and compatible Android/iOS tooling.
- Complete business onboarding, publish a workflow, and obtain its **release ID**.
- Issue a publishable key whose integration permits that release.
- Deploy a compatible backend; the default API is `https://luli-api.luliverify.io`.
- Do not use a workflow/draft ID or a private merchant key in these fields.

From the repository root:

```sh
flutter pub get
cd example
flutter pub get
flutter run
```

Select the desired device when prompted or use `flutter devices` and
`flutter run -d DEVICE_ID` with an actual returned device ID.

## Configuration

Enter the publishable key and release ID in the UI, or prepopulate them through
a local Dart-define file:

```json
{
  "PUBLISHABLE_KEY": "YOUR_PUBLISHABLE_KEY",
  "RELEASE_ID": "YOUR_PUBLISHED_RELEASE_ID",
  "API_BASE_URL": "https://luli-api.luliverify.io",
  "RETURN_URL": "https://app.your-domain.example/verification-return"
}
```

```sh
flutter run --dart-define-from-file=/absolute/path/to/local-sdk-config.json
```

Every value above is a placeholder. Keep real account configuration outside the
repository. Dart defines are compiled into the application and are not secret
storage. Never include passwords, private merchant keys, tokens or tickets.

`PUBLISHABLE_KEY`/`RELEASE_ID` populate form fields. `RETURN_URL` populates the
hosted return field. `API_BASE_URL` overrides the API endpoint; it must be HTTPS.
The example starts in native mode; use the switch for hosted mode.

## Native mode

Leave “Use hosted browser flow” off. The SDK creates/exchanges native session
access and displays the published backend workflow. No return URL is required.

The example’s status message is advisory. `completed` means the native session
finished, not that the business should grant access automatically. Current
backend execution is test-only; real provider liveness and OTP delivery remain
unintegrated. Customer screens omit test notices, while API metadata keeps them.

## Hosted mode and returning to this app

Enable “Use hosted browser flow” and supply an exact integration-registered HTTPS
return URL. The SDK opens the hosted site externally and waits for a matching
App Link / Universal Link while its route remains alive.

**The checked-in example does not configure OS link associations.** Merely typing
a URL here does not make it open the app. To finish a real return flow:

1. Choose a return address on a domain you control.
2. Register that exact address on the backend integration.
3. Add Android's verified VIEW intent filter and host `assetlinks.json` for the
   actual package/signing certificate.
4. Add iOS Associated Domains and host `apple-app-site-association` for the actual
   Apple team/bundle identity and return paths.
5. Configure Flutter/app_links handling consistently, then verify on installed
   apps/devices that the browser link opens the app.

A successful matching link reports `hostedReturned`, not verification approval.
A cold start after the OS kills the app does not restore this SDK's in-memory
flow. See the [integration guide](../docs/INTEGRATION.md) and the
[package README](../README.md#hosted-browser-flow) for the full contract.

## Platform testing

Android uses API 24+; the manifest already includes INTERNET permission. The
camera/file plugins handle on-demand permission/selection. The dedicated Android
emulator used in the smoke test needs `-camera-front emulated` to exercise capture.

The iOS example already contains camera/photo-library usage descriptions. Simulator
builds and screens have been checked, but actual front-camera capture requires a
physical iPhone. The tested simulator's native Files provider returned “Content
Unavailable”; complete iOS upload validation is still pending.

[Android report](../docs/ANDROID_SMOKE_TEST.md) ·
[iOS report](../docs/IOS_SMOKE_TEST.md)

## Validation commands

From `example/`:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
```

The iOS build requires macOS/Xcode. Supply your local Dart-define file to build
commands if you want prefilled development fields. Otherwise the app asks for
configuration at runtime. Example tests check the host; run `flutter test` from
the package root for SDK contract, transport, UI and callback tests.
