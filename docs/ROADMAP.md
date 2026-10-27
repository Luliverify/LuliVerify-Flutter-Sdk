# Delivery Status

Implemented locally:
- Native backend launch/exchange channel, resume and browser/native separation.
- Typed backend parsers and revision-safe session orchestration.
- Native HTTP and multipart transport, expiry/cancellation/recovery primitives.
- Native scalar forms, consent, basic camera and document selection.
- Hosted browser launch and explicit app-return validation.
- Single-call publishable-key native/hosted launcher and Android/iOS example.
- Custom branded mobile controls with bundled Geist and Lucide outline icons.

Before production release:
- Deploy the accompanying backend changes and exercise merchant authorization.
- Integrate provider-supported native liveness and actual OTP delivery.
- Test physical-device capture, denied permissions, interruption and recovery.
- Configure and test each merchant app's OS-verified app/universal links.
- Validate privacy disclosures, license and device/version compatibility matrix.
- Mirror the proven contracts/behavior in React Native; it remains a scaffold.

Current execution is test-only. There is no public package release or claim of
production identity verification readiness.
