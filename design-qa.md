# Identity Atlas design QA

## Comparison target

Approved source assets:

1. `Web/assets/brand/identity-atlas-logo.svg`
2. `Web/assets/brand/identity-atlas-mark.svg`

State: Development-tenant Access explorer showing a selected authentication-method path.

## Viewport and normalisation

The browser CSS viewport was 1280 by 720 pixels at device density 1. The captured page was 1265 by 712 pixels because the browser excluded its scrollbars.

The source logo is 210 by 48 pixels. The live SVG reports the same intrinsic size and renders at exactly 210 by 48 CSS pixels. The combined comparison uses a one-to-one crop of the live header logo, so neither logo was resized for the comparison.

## Full-view comparison

The live capture shows the approved logo in the existing 248-pixel utility-header brand region. The 18-pixel horizontal inset and 15-pixel vertical inset keep the 210 by 48 logo centred without changing the height or spacing of the header.

The logo remains distinct from the collection status and tenant metadata. No report controls, graph content or navigation items overlap the brand region.

## Focused comparison

The combined comparison places the approved 210 by 48 source beside a one-to-one browser crop. The wordmark, cartographic cut, node, globe, colours, transparency and proportions are the supplied artwork rather than a rebuilt approximation.

Browser screenshot antialiasing softens the preview slightly. The page loads the original SVG paths at their intrinsic size, so the rendered asset remains resolution-independent.

## Required fidelity surfaces

### Fonts and typography

The approved Space Grotesk lettering is stored as SVG paths. Its shape, weight, tracking and ENTRA-to-ATLAS hierarchy do not depend on a locally installed font or an external font request.

### Spacing and layout rhythm

The logo fills the available brand area without touching its borders. It retains the existing 78-pixel header height and aligns vertically with the collection status and metadata.

### Colours and visual tokens

The approved navy, teal and white values are unchanged. They remain consistent with the existing navigation, action and surface colours.

### Image quality and asset fidelity

The supplied SVG is used directly. It loads successfully with a natural size of 210 by 48 pixels and is complete before capture. A matching globe-only SVG is used for the browser icon.

### Copy and content

The browser title remains Identity Atlas. The header image has the alternative text Identity Atlas and remains inside the page's level-one heading.

## Findings

No actionable P0, P1 or P2 differences were found.

## Interaction and accessibility checks

1. The live report loaded from `http://127.0.0.1:8766/`.
2. The page retained the expected live-tenant object count.
3. The full logo and globe browser icon both returned HTTP 200 as local SVG assets.
4. The logo exposed the alternative text Identity Atlas.
5. Reloading the report retained the logo and the current explorer state.
6. The browser console contained no errors.
7. Twenty-two PowerShell tests and eight browser-worker tests passed.

## Comparison history

### Pass 1

P2: The initial 24-pixel header inset reduced the approved 210 by 48 logo to 199 by 45.5 pixels.

Fix: Reduced the header inset to 18 pixels and rendered the approved asset at its intrinsic 210 by 48 size.

Post-fix evidence: `IdentityAtlas-logo-live-integration.png` and `identity-atlas-logo-integration-comparison.png`.

### Pass 2

No actionable P0, P1 or P2 differences remain.

## Follow-up polish

No logo-specific follow-up is required.

final result: passed
