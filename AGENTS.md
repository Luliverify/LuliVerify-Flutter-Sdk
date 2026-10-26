# SDK Working Rules

- Backend field contracts, options, evidence roles and revisions are authoritative.
- Never spoof browser Origin headers to enable native authentication.
- Never bundle merchant secrets or log session tokens, images or personal data.
- A selfie does not prove liveness; callbacks do not prove final approval.
- Keep transport, orchestration, presentation and device adapters separate.
- This is a scaffold. Do not claim native verification is operational.
- Maintain parity with the sibling React Native SDK; do not incidentally edit it
  or the backend. No guessed endpoints or silent native-to-web fallback.
- Run package and example formatting, analysis and tests after changes.
