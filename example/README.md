# LuliVerify Flutter example

Use this application to try the SDK’s native and hosted presentations. It calls
`LuliVerify.launch` and lets the SDK handle verification screens and navigation.

## Run

Have your LuliVerify publishable key and permitted workflow release ID ready.
From the repository root:

```sh
flutter pub get
cd example
flutter pub get
flutter run
```

Select an available Android or iOS device, then enter your credentials on the
example screen. Use a publishable key, not a private account key. Choose the
published release ID rather than a workflow/draft ID.

## Optional configuration file

Prepopulate the fields with a local Dart-define file:

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

These values are placeholders. Keep real configuration outside the repository.
Dart defines are compiled into the application, so use only public configuration;
never include passwords, private keys, session tokens, or launch tickets.

## Choose a presentation

**Native:** leave “Use hosted browser flow” off. The SDK displays the workflow
configured in LuliVerify, including its fields and evidence requirements. No
return URL is needed.

**Hosted:** turn the switch on and enter your registered HTTPS return URL. The SDK
opens the hosted verification website in the external browser. To return to your
app, configure the address as an Android App Link and iOS Universal Link for your
own domain and signed application. The field alone does not install those
associations.

See the [hosted integration guide](../docs/INTEGRATION.md#hosted-integration) and
[platform setup](../README.md#android-setup) for the required configuration.

## Handle the result

The example displays the status returned by the SDK. Native session completion
and a hosted return are different events. Use your authorized LuliVerify
integration to retrieve the verification result before making access decisions.

The launch Future belongs to the application process that opened it. If the app
restarts, restore normal app navigation and retrieve the session result separately.

## Platform configuration

Android requires API 24+; the example includes INTERNET permission. Configure the
camera and return-link behaviour appropriate to your application.

iOS requires 13.0+; the example includes camera/photo-library usage descriptions.
Use a physical device for camera capture and permission validation.

For hosted returns, add your Android intent filter and signing association file,
and your iOS Associated Domains entitlement and association file. Use the actual
package ID, signing fingerprints, Apple team ID, and bundle ID for your build.

## Validation commands

From `example/`:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
```

The iOS build requires macOS/Xcode. Add your local Dart-define file to a build
command if you want prefilled fields. Run `flutter test` from the package root
for SDK contract, transport, UI, and callback tests.
