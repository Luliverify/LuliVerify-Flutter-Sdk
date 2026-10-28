# LuliVerify native design

Source: user-approved mobile redesign using brand references from Figma file
KZr0UhszVsbris1jaDzCTc, frame 2106:11838. The desktop builder is not reproduced.

- Default primary: #1F3FE2. Backend primaryColor overrides it only when it keeps
  white labels at WCAG 4.5:1 contrast. Inadequate colors fall back to the default.
- Ink #202431, secondary text #5D6375, pale surface #F2F4FD, border #D9DCE7.
- Bundled Geist (OFL), 30px task headings, 16px body/actions, 14px field labels.
- 12px input/control radii. Primary/secondary action radius follows backend
  buttonRadius when provided (0-32), default 12. 24px horizontal page padding.
- Custom full-width actions, wrap-safe external field labels, branded selection
  sheets, explicit consent controls, notices and evidence actions.
- Consistent Lucide outline icons; no Material/Cupertino icon assets.
- Host theme remains untouched. The SDK route supplies its own scoped theme
  and English Material localizations so a Cupertino host needs no MaterialApp.
- Backend displayName, primaryColor, buttonRadius, field/option/step text and
  action labels are consumed. Geist remains the bundled typeface; arbitrary
  backend font names are not downloaded or executed.
- Scrollable narrow/large-text layouts and safe areas accommodate keyboards.
  Loading, disabled, failed, expired, terminal and recovery states are explicit.
- Test/simulation metadata stays in the API; customer screens use ordinary capture instructions. Completion describes session
  submission, not an independently verified identity or merchant approval.

## Verification and provenance

Business, liveness and 320px/1.6x text layouts were rendered from sanitized
backend contract fixtures via test/native_design_test.dart. User-provided brand
color/name are applied to those synthetic captures; no customer data is used.
Test images are generated locally only with DESIGN_CAPTURE=1. No screenshot
or Figma raster is embedded in the shipping interface.

Finish review: task controls, font/icon geometry, label wrapping, selection
options and simulation messaging inspected. The label truncation found in the
first render was corrected and the second render confirmed it. Verdict: ready
for development integration testing; real-device/provider gates remain open.
