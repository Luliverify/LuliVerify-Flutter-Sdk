# Native SDK Example

Run `flutter pub get`, then `flutter run` on Android or iOS. Enter the publishable
key and permitted published release ID. The example calls LuliVerify.launch;
it does not create SDK routes/controllers. Never paste a private merchant key.
Use API_BASE_URL, PUBLISHABLE_KEY, RELEASE_ID and RETURN_URL dart-defines to
preconfigure your own development environment; no credentials are bundled.

Matching native backend endpoints must be deployed first. No credentials,
customer records or fabricated provider outcomes are bundled with this app.
Select hosted mode and supply an integration-registered HTTPS return URL to test
the browser flow. Configure OS app links/domain association first; a callback
only reports navigation. Native mode requires no return URL.
See [integration guide](../docs/INTEGRATION.md) for permissions and lifecycle rules.
