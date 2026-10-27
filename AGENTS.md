# SDK Working Rules

- Backend field contracts, options, evidence roles and revisions are authoritative.
- Never spoof browser Origin headers to enable native authentication.
- Never bundle merchant secrets or log session tokens, images or personal data.
- A selfie does not prove liveness; callbacks do not prove final approval.
- Keep transport, orchestration, presentation and device adapters separate.
- This is a development SDK. Do not claim provider liveness or production
  readiness based on client tests or simulator builds alone.
- Maintain parity with the sibling React Native SDK; do not incidentally edit it
  or the backend. No guessed endpoints or silent native-to-web fallback.
- Run package and example formatting, analysis and tests after changes.
