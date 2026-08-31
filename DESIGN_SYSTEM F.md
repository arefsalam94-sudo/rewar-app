# DESIGN_SYSTEM.md
## Authoritative Cross-Theme Design Specification

**Status:** Approved design foundation for implementation.  
**Scope:** Entire application, including screens that already exist and screens created later.  
**Theme rule:** Light and Dark are the **same design system**. Geometry, component structure, blur logic, glass behavior, opacity logic, depth, spacing, interaction states, icon rules, touch targets, and responsive behavior must remain the same. Theme files change **colors/tints only** unless this document explicitly defines an exception.

---

## 1. Source-of-truth hierarchy

When implementing or reviewing UI, use this order:

1. `DESIGN_SYSTEM.md` — structure, behavior, geometry, glass, depth, component rules.
2. Active theme file:
   - `DESIGN_LIGHT.md`
   - `DESIGN_DARK.md`
3. Approved reference screenshots for visual comparison.
4. Existing implementation only when it does not conflict with the files above.

Do **not** preserve an old implementation merely because it already exists.

Do **not** invent a new component appearance for a new screen. Reuse this system. A genuine exception must be explicitly documented in this file before it becomes part of the design language.

---

## 2. Design philosophy

The application uses a premium nature/travel visual language built around full-screen photography, theme-specific gradient overlays, highly translucent iOS-inspired liquid glass, clear depth through sheen/refraction-like edge lighting/blur/soft shadows, rounded organic geometry, consistent semantic typography, and calm spacing.

The target is **liquid glass**, not flat frosted cards and not opaque translucent panels.

A glass surface should feel transparent, glossy, light-catching, layered, softly refractive, and visually separated from the background without becoming heavy. The background must remain recognizable through glass while text stays readable.

---

## 3. Light / Dark parity — mandatory

The following values and behaviors are shared across Light and Dark:

- background-photo blur
- background-gradient opacity
- glass blur
- glass fill-opacity structure
- glass edge thickness
- glass sheen structure
- glass shadow geometry
- component radii
- component heights
- spacing
- touch targets
- selected/unselected behavior
- recessed input behavior
- stacked-glass progression
- toolbar structure
- card structure
- icon-container structure
- responsive breakpoints
- RTL behavior

Only theme tokens such as colors, tints, text colors, accent colors, and semantic state colors change.

**A Dark-mode component must not become more blurred, more opaque, more rounded, deeper, or structurally different simply because the theme is Dark.**

---

## 4. Background system — mandatory

### 4.1 Every screen uses a photo

Every screen must have a background photograph supplied as a bundled local asset.

- Do not replace the photo with a flat color or gradient.
- The developer supplies/assigns each screen's image asset in the project.
- Do not load required screen backgrounds from the network.
- Different screens may use different images.

### 4.2 Layer order

Bottom to top:

1. background photo
2. theme gradient overlay
3. page content and liquid-glass surfaces

This order is the same in Light and Dark.

### 4.3 Background-photo blur

Use a **minimal global background blur**:

- `backgroundPhotoBlurSigma: 2`
- same value in Light and Dark
- do not add a stronger Dark-only blur
- do not stack an additional full-screen blur unless explicitly required by a future approved design

The goal is to keep the image softly integrated while making it slightly more visible than the previous Light reference.

If a source photo is already artistically blurred, do not pre-blur the asset again; the runtime background treatment must still remain structurally identical between themes.

### 4.4 Gradient overlay

Use the theme's own gradient colors with:

- `backgroundGradientOpacity: 0.45`
- acceptable implementation-tuning range: `0.42–0.46`
- the chosen production value must be the same in both themes
- default direction: top → bottom
- uniform across the entire screen
- no Dark-only vignette
- no region that reverts to a flat background
- safe areas use the same continuous background treatment

Do not increase overlay opacity to solve readability. Improve the local glass surface behind the content instead.

---

## 5. Base liquid-glass material — mandatory

There is one default liquid-glass material for the application. It is reused for glass cards, informational cards, secondary buttons, social buttons, language options, filter containers, filter controls, popup menus, bottom sheets, floating toolbar / bottom navigation, selectable glass surfaces, glass back buttons, auxiliary glass controls, and future components intended to be glass.

### 5.1 Base glass recipe

| Property | Rule |
|---|---|
| Backdrop blur | `σ = 18` |
| Glass sheen | neutral white vertical sheen, approximately `24% → 8%` |
| Theme tint | subtle theme glass tint at approximately `6%` |
| Neutral glass edge | `1px`, soft/light-catching, not a selection indicator |
| Top/upper highlight | visible but soft; strongest near the light-facing edge |
| Shadow | low-opacity, wide, fully faded, small offset |
| Background visibility | clearly visible but softened |
| Saturation | optional slight preservation boost (`~1.05–1.10`) if renderer supports it |
| Hard opaque fill | prohibited for ordinary glass |

The glass must not look like a flat white/green/black panel.

### 5.2 Glass edge vs selection stroke

**Neutral glass edge**
- belongs to the material itself
- subtle
- visible on both selected and unselected glass
- must not communicate selection

**Selection/focus stroke**
- semantic state indicator
- theme accent color
- appears only when the control is selected/active/focused
- visibly stronger than the neutral glass edge

Never use the ordinary glass edge as the selected-state indicator.

### 5.3 Soft floating shadow

Default floating-glass shadow:

- small vertical offset
- wide blur
- low opacity
- no hard edge
- no tight Material-style elevation shadow
- must fully fade into the background

Suggested starting geometry:

- `offsetY: 6`
- `blurRadius: 22`
- `spreadRadius: 0`
- alpha approximately `0.12–0.16`

The shadow supports the glass effect; it does not replace transparency, sheen, edge lighting, or depth.

---

## 6. Stacked liquid glass

When glass surfaces overlap, depth is created by **progressive blur + inter-layer shadow**, not by increasing fill opacity.

### 6.1 Blur progression

| Layer | Typical use | Blur |
|---|---|---|
| L1 — base | outer card / main glass surface | `σ = 18` |
| L2 — middle | group card / sheet on L1 | `σ = 22` |
| L3 — top | glass control / chip / floating sub-surface on L2 | `σ = 26` |

Rules:

- blur rises gently with depth
- fill-opacity structure stays the same
- theme tint strength stays the same unless state styling requires otherwise
- do not exceed L3 for ordinary UI
- if four visual glass layers appear necessary, flatten the hierarchy instead
- never turn the top layer into an opaque frost wall

### 6.2 Inter-layer shadows

- L2 casts a soft shadow onto L1
- L3 casts a soft shadow onto L2
- shadow is fully faded
- low opacity
- small offset
- wide blur
- no visible boundary line

The user should perceive that one glass sheet sits above another without seeing a hard shadow edge.

---

## 7. Selection, focus, and control states — global

This rule applies to language options, filters, category choices, selectable cards, option tiles, multi-select chips, focusable glass fields, and future selectable glass controls.

### 7.1 Unselected / inactive

- use normal base liquid glass
- apply a very subtle theme tint
- **no accent selection stroke**
- neutral glass edge may remain because it belongs to the material
- no strong fill inversion

### 7.2 Selected / active

- keep the surface translucent and liquid-glass
- strengthen the theme tint/fill while preserving background visibility
- add the theme-specific accent stroke
- recommended stroke width: `1.5px`
- recommended selected tint strength: approximately `14–18%`
- optional extremely soft accent glow is allowed if it remains subtle
- selected state must be obvious at a glance

Selected does **not** mean turning ordinary selectable glass into a fully opaque block.

### 7.3 Focused text field

Focused field = selected-state treatment for inputs:

- keep recessed glass
- add theme accent stroke
- preserve inner depth
- do not replace the glass with a solid fill

### 7.4 Error

- keep the same geometry and glass material
- error color replaces the focus/selection stroke
- helper/error message uses the theme error color
- do not remove the field's recessed depth

### 7.5 Disabled

- retain component structure
- reduce emphasis to approximately 40% overall interactive strength
- no accent selection stroke
- no active glow
- maintain readable disabled text contrast

### 7.6 Success / warning / information

Semantic states use the theme's semantic color token while preserving the component's existing material and geometry.

Do not invent a separate card language for success, warning, error, or info.

---

## 8. Input fields — recessed liquid glass

All standard form/search/text inputs use the same recessed style in both themes.

Examples: Login, Register, Search, Booking forms, Profile forms, and future data-entry screens.

### 8.1 Visual relationship

- outer card/panel = floating liquid glass
- field inside it = recessed/inset liquid glass

The field should feel slightly deeper than its parent, like the approved Dark Register reference, but softened so it remains glass rather than a carved solid box.

### 8.2 Input recipe

- control height: `56dp`
- radius: `14px`
- base glass material retained
- subtle theme tint
- soft inset/inner shadow
- neutral glass edge when inactive
- accent stroke on focus
- error stroke on validation error
- text and hint colors come from semantic typography tokens

Suggested inner-depth starting point:

- inner shadow offset: `0, 2`
- inner shadow blur: `10`
- low opacity (`~0.14`)
- no sharp inner border

If the framework has no native inset shadow, reproduce the appearance with layered decoration/painting rather than dropping the depth effect.

---

## 9. Buttons

### 9.1 Primary page actions

Examples: Log In, Register, Send Code, Create Account, Continue.

Rules:

- solid theme action color
- theme on-action text color
- height: `56dp`
- radius: `14px`
- no heavy elevation
- subtle soft shadow allowed
- full-width where the page layout calls for a primary action
- 48dp minimum touch target always satisfied

### 9.2 Secondary / auxiliary buttons

Examples: Apple, Gmail, alternative actions, secondary confirmation surfaces.

Use liquid glass, not a second opaque button language.

When a secondary button sits on another glass surface, apply the stacked-layer rule.

### 9.3 Small card CTAs

Small CTAs embedded in cards remain pill-shaped.

Keep the existing compact proportions:

- visual height around `40dp`
- minimum tap target `48dp`
- pill radius
- label + directional arrow when applicable

The small card CTA is a compact action style and does not redefine the large primary button.

---

## 10. Cards

### 10.1 Standard cards

- radius: `28px`
- same radius in Light and Dark
- use liquid glass when the design calls for a glass card
- preserve generous internal spacing
- do not use theme-specific radius variants

### 10.2 Informational cards

Informational cards use the same liquid-glass material.

Do not fill them with the full-screen brand gradient.

### 10.3 Image cards

Where photography is part of the card:

- image remains the visual subject
- use theme-appropriate overlays only as needed for text legibility
- controls on top may use compact glass or semantic badge styles
- do not cover the image with an opaque glass wall

---

## 11. Icons

### 11.1 Feature/category icons

For feature/category icons such as Explore Nature, Where to Stay, Policy categories, facilities, and similar destinations:

- circular container
- **stroke only**
- no solid fill
- theme accent color for circle and icon
- icon centered
- use consistent size across equivalent card types

Recommended default:

- circle: `44–46dp`
- icon: `22–24dp`
- stroke: `1.5px`

### 11.2 Utility icons

Menu, globe, eye, chevrons, and other utility icons do not require a circle unless their component explicitly uses one.

### 11.3 Back button

- circular liquid-glass control
- visible circle approximately `36dp`
- minimum tap target `48dp`
- left chevron
- physically placed top-left even in RTL, unless a future approved design explicitly changes this
- theme-appropriate icon color

---

## 12. Filters

Filter regions use a liquid-glass container, standard spacing, and selectable controls using the global selected/unselected state.

### 12.1 Filter chips/options

**Unselected**
- lightly theme-tinted liquid glass
- no accent selection stroke

**Selected**
- stronger translucent theme tint/fill
- theme accent stroke (`1.5px`)
- may include a checkmark, but the checkmark is secondary to the visible selected state

- visual height around `38dp`
- minimum tap target `48dp`
- pill geometry when chip-like
- use `Wrap`/responsive flow when labels can vary by language

---

## 13. Rating components

Ratings use one consistent component family throughout the application.

Two forms are approved:

1. numeric score badge (example: `8.2`)
2. star-rating badge/row

Rules:

- keep score and stars visually separate when both are displayed
- compact rounded box
- radius: `12px`
- consistent padding and height across screens
- maintain high contrast
- theme files define the rating fill/stroke/content colors
- rating values and stars remain LTR in every language
- do not redesign rating structure per screen

Rating badges are semantic badges, not ordinary base-glass cards.

---

## 14. Step indicator (multi-step flows)

Multi-step flows (checkout, and any future wizard) show progress with one
shared component. It is drawn once, at the top of the flow, inside its own
base-glass surface — never re-invented per step.

Structure:

1. one circle per step, containing the step **number**
2. connector dots between adjacent circles
3. the step **label** beneath each circle

Rules:

- circle diameter: `56px`; connector dots: `5` per gap, `4px` each
- the **active** step carries an accent ring (`2px`) around its circle, with
  its number and label in the accent color
- a **completed** step is filled solid with the accent and shows a check glyph
  in place of its number; its connector to the next step is drawn in the accent
  color rather than the neutral dot color
- an **upcoming** step is neutral on-glass: no ring, no fill
- the three states must stay visually distinct without relying on color alone —
  the check glyph is what separates completed from active for a viewer who
  cannot tell the ring from the fill
- circles sit on the shared glass material; the surrounding surface is one
  base-glass panel, not one panel per step
- labels use the caption size from the type scale and never truncate mid-word;
  they wrap instead
- theme files define the ring, number, dot, and label colors
- the row **mirrors** in RTL like any other content order — step 1 sits on the
  reading-start side, per section 21
- do not attach tap handlers to future steps: a step indicator reports
  position, it does not navigate forward past unvalidated input

---

## 15. Bottom navigation / floating toolbar

Keep the existing interaction concept, but execute it with the global liquid-glass system.

### Structure

- floating pill
- height: `74dp`
- side inset: approximately `20dp`
- same geometry in Light and Dark
- base liquid glass
- glossy/light-catching edge
- subtle soft shadow
- background remains visible through the bar

### Active destination

Keep the current filled-circle active destination concept as an explicit navigation exception to the generic selection-stroke rule.

- active circle: `48dp`
- active color from theme
- inactive destinations remain visually quieter
- selected navigation should look polished and intentional, not like a generic chip

---

## 16. Popup menus and bottom sheets

All popup menus, sheets, dropdown surfaces, and floating overlays use the same liquid-glass material.

Their depth level determines whether they use L1, L2, or L3 blur.

- do not invent a separate popup glass recipe
- contents must scroll when space is limited
- bottom sheets should remain usable on short screens and with large system fonts
- stacked sheet content follows inter-layer shadow rules

---

## 17. Typography

Typography geometry is shared across themes. Theme files only define text colors.

### 16.1 Font families

- English UI: **Plus Jakarta Sans**
- Arabic UI: **Dubai**
- Kurdish UI: current system fallback until the intended Kurdish font is bundled
- Approved onboarding/display exception: **Unbounded** may remain where already intentionally used

### 16.2 Semantic type scale

Use the same token names in both themes:

| Token | Size | Weight | Line height | Use |
|---|---:|---:|---:|---|
| `display` | 48 | 700 | 56 | large hero/onboarding display |
| `display-mobile` | 32 | 700 | 40 | compact display |
| `page-title` | 28 | 700 | 36 | main screen title |
| `section-title` | 20 | 600 | 28 | section heading |
| `card-title` | 18 | 600/700 | 24 | card title |
| `body-lg` | 16 | 400 | 24 | primary body |
| `body-sm` | 14 | 400 | 20 | secondary body |
| `label` | 12 | 600 | 16 | labels/metadata |
| `caption` | 12 | 400 | 16 | hints/captions |

Preserve the current visual typography as closely as possible when migrating existing screens. Normalize token names; do not arbitrarily resize every screen.

### 16.3 Text roles

Every text element must use a semantic role:

- heading/title
- body
- secondary/helper
- hint/placeholder
- link/action
- disabled
- error
- text-on-action
- text-on-glass

Theme files define the actual colors/opacity for those roles.

---

## 18. Spacing and layout

Use an `8dp` primary rhythm with `4dp` half-step support.

Recommended spacing tokens:

- `space-1: 4`
- `space-2: 8`
- `space-3: 12`
- `space-4: 16`
- `space-5: 20`
- `space-6: 24`
- `space-8: 32`
- `space-12: 48`

Do not invent arbitrary spacing values when an existing token works.

---

## 19. Responsive behavior

The same design system must work across phones, tablets, and wider layouts.

### Breakpoints

- Compact: `< 600dp`
- Medium: `600–839dp`
- Expanded: `>= 840dp`

### Compact

- 4-column layout logic where a grid is needed
- 16dp page side margin
- components stack vertically when necessary
- horizontal filters may scroll or wrap
- preserve 48dp minimum touch targets

### Medium

- 24dp page side margin
- use additional columns where content benefits
- maintain readable maximum card widths

### Expanded

- 12-column layout logic where appropriate
- centered content region
- recommended content max width: approximately `1200dp`
- do not scale every component proportionally; preserve ergonomic control sizes

Text may wrap or reflow. Do not solve responsiveness by shrinking text below the defined hierarchy.

---

## 20. Accessibility

### Minimum touch target

Every tappable control must provide at least `48 × 48dp` of hit area even when the visible control is smaller.

### Contrast

- body/important text should target at least 4.5:1
- do not darken text to compensate for a busy photo
- strengthen the local glass surface or local text scrim instead
- selected state must not rely on color alone when an additional check/icon can improve clarity, but the primary visual state must remain visible without the check

### Large text

- avoid fixed-height containers that clip text
- use wrapping and flexible layout
- modal content must scroll
- labels beside icons/actions must have room to shrink/wrap safely

---

## 21. RTL and directionality

The app supports LTR and RTL.

- leading/trailing layout mirrors automatically
- content order mirrors where language direction requires it
- forward chevrons mirror with direction
- rating values, star progress, OTP codes, phone/dial codes, and similar measurement/data sequences remain LTR
- back button remains physically top-left with a left chevron as an explicit approved exception
- avoid manually hard-coding left/right where `start/end` semantics are appropriate

---

## 22. Theme-specific values

This file must not duplicate Light/Dark color values.

Use:

- `DESIGN_LIGHT.md` for Light colors/tints
- `DESIGN_DARK.md` for Dark colors/tints

The theme files must expose the same token names one-for-one.

If a token exists in one theme but not the other, the design system is incomplete.

---

## 23. Prohibited legacy patterns

Do not reintroduce:

- Dark-only stronger background blur
- Dark-only stronger glass blur
- per-theme component radii
- green/emerald brand gradients as ordinary card/input fills
- fully opaque ordinary glass surfaces
- unselected accent strokes
- selection communicated only by a checkmark
- different input families on different screens
- flat frosted panels pretending to be liquid glass
- fill-opacity ramps for stacked glass
- per-screen random glass recipes
- separate typography token names between themes
- old 50/80% overlay conflicts
- old 20/40 glass-blur conflicts
- screen-specific structural differences between Light and Dark

---

## 24. Implementation order for a redesign pass

When applying these files to an existing codebase:

1. update theme tokens
2. update background component
3. update base liquid-glass component
4. update stacked glass support
5. update input component
6. update button components
7. update selection/focus state handling
8. update shared cards
9. update filters
10. update icon containers
11. update bottom navigation
12. update popup/bottom-sheet surfaces
13. migrate existing screens to shared components
14. audit Light/Dark parity
15. visually compare against approved screenshots

Do not rewrite backend logic, navigation logic, validation logic, localization, or data behavior unless a UI requirement directly requires a presentation-layer change.
