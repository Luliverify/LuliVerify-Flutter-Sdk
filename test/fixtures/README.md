# Fixture Provenance

`business_session.json` was generated from backend commit `4b1ec0a` using
`groupedDefinition(workflowTemplate(..., 'business'))` and
`definitionContracts(..., toolCapabilities)`. Field, upload and submission metadata
are actual backend-generated values; envelope/session timestamps and IDs are
synthetic. There is no customer data, usable credential or provider response.

This validates payload parsing, not native authentication or live verification.
Regenerate and review fixtures when the backend contract changes. Both mobile
SDKs should eventually consume the same versioned sanitized contract fixtures.
