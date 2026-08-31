| `step-complete-fill` | `#0E2A44` |
| `step-complete-content` | `#FFFFFF` |
| `step-connector-done` | `#0E2A44` |
# DESIGN_LIGHT.md
## Lush Horizon — Light Theme Tokens

**Role:** Theme-specific values only.  
**Structure and behavior:** Defined by `DESIGN_SYSTEM.md`.  
**Rule:** Do not redefine geometry, blur, radii, component behavior, or spacing here.

---

## 1. Core palette

| Token | Value |
|---|---|
| `surface` | `#F9F9F9` |
| `surface-dim` | `#DADADA` |
| `surface-bright` | `#F9F9F9` |
| `surface-container-lowest` | `#FFFFFF` |
| `surface-container-low` | `#F3F3F3` |
| `surface-container` | `#EEEEEE` |
| `surface-container-high` | `#E8E8E8` |
| `surface-container-highest` | `#E2E2E2` |
| `on-surface` | `#1B1B1B` |
| `on-surface-variant` | `#3E4945` |
| `outline` | `#6E7A74` |
| `outline-variant` | `#BDC9C3` |
| `primary` | `#00624D` |
| `on-primary` | `#FFFFFF` |
| `primary-container` | `#187C64` |
| `on-primary-container` | `#BEFFE8` |
| `action` | `#0E2A44` |
| `on-action` | `#FFFFFF` |
| `secondary` | `#516257` |
| `on-secondary` | `#FFFFFF` |
| `tertiary` | `#3F5774` |
| `on-tertiary` | `#FFFFFF` |
| `error` | `#BA1A1A` |
| `on-error` | `#FFFFFF` |
| `error-container` | `#FFDAD6` |
| `on-error-container` | `#93000A` |

---

## 2. Background

| Token | Value |
|---|---|
| `background-gradient-top` | `#E1F4E5` |
| `background-gradient-bottom` | `#187C64` |
| `background-gradient-opacity` | `0.45` |
| `background-photo-blur-sigma` | `2` |

The opacity and blur values are shared with Dark mode. Only the gradient colors differ.

Every screen must use a developer-supplied background photograph.

---

## 3. Liquid-glass theme tint

The base glass material comes from `DESIGN_SYSTEM.md`.

Light-specific tint tokens:

| Token | Value |
|---|---|
| `glass-tint` | `#E1F4E5` |
| `glass-tint-opacity` | `0.06` |
| `glass-edge` | white/light neutral |
| `glass-shadow-color` | `#0E2A44` |
| `glass-shadow-opacity` | `0.14` |
| `glass-inner-shadow-color` | `#0E2A44` |
| `glass-inner-shadow-opacity` | `0.14` |

The glass itself must remain transparent. The mint tint is subtle and must not turn the surface into a mint card.

---

## 4. Selection and focus

| Token | Value |
|---|---|
| `selection-accent` | `#00624D` |
| `selection-tint` | `#E1F4E5` |
| `selection-tint-opacity` | `0.16` |
| `selection-stroke-opacity` | `0.90` |
| `selection-stroke-width` | `1.5px` |
| `focus-accent` | `#00624D` |

### Unselected

- lightly mint-tinted liquid glass
- no accent selection stroke
- only the neutral glass edge is present

### Selected / focused

- same liquid-glass structure
- stronger translucent mint tint
- `#00624D` accent stroke
- background remains visible through the control

Do not use a fully opaque navy/green fill for ordinary selectable glass controls unless the component is explicitly defined as a solid primary action.

---

## 5. Primary and secondary actions

### Primary action

- fill: `#0E2A44`
- text/icon: `#FFFFFF`
- geometry comes from `DESIGN_SYSTEM.md`

### Secondary action

Use the Light liquid-glass material.

Do not create a separate opaque secondary-button style.

---

## 6. Text roles

| Role | Value |
|---|---|
| `text-heading` | `#1B1B1B` |
| `text-body` | `#1B1B1B` |
| `text-secondary` | `#3E4945` |
| `text-hint` | `#6E7A74` |
| `text-link` | `#0E2A44` |
| `text-on-action` | `#FFFFFF` |
| `text-on-glass` | `#1B1B1B` |
| `text-disabled` | `#6E7A74` at reduced emphasis |
| `text-error` | `#BA1A1A` |

### Usage

- headings stay strong and high contrast
- body text uses `text-body`
- subtitles/helper text use `text-secondary`
- placeholders/hints use `text-hint`
- interactive text uses `text-link`
- focused/selected text remains readable and does not change randomly per screen

On a dark area of a photograph where normal Light-theme text would lose contrast, place the text on an appropriate glass surface or use the approved on-photo treatment rather than changing global typography rules.

---

## 7. Icon colors

| Role | Value |
|---|---|
| `icon-accent` | `#0E2A44` |
| `icon-feature-ring` | `#0E2A44` |
| `icon-on-action` | `#FFFFFF` |
| `icon-selected` | `#00624D` |

Feature/category icons remain stroke-only circles with no fill.

---

## 8. Bottom navigation

| Token | Value |
|---|---|
| `nav-active-fill` | `#0E2A44` |
| `nav-active-icon` | `#FFFFFF` |
| `nav-inactive-icon` | `#0E2A44` |
| `nav-label` | `#0E2A44` |

The bar itself uses the shared liquid-glass material.

---

## 9. Rating badges

Preserve the approved screenshot structure.

### Numeric score and star badge

| Token | Value |
|---|---|
| `rating-fill` | `#0E2A44` at approximately `0.88` |
| `rating-content` | `#FFFFFF` |
| `rating-accent` | `#E1F4E5` |
| `rating-stroke` | `#FFFFFF` at low opacity |

Keep score and stars visually clear, compact, and high contrast.

Do not use a different rating structure on different screens.

---

## 10. Step indicator

Tokens for the multi-step flow indicator (`DESIGN_SYSTEM.md` section 14).

Step state is drawn in `primary-container`, **not** `action`: the approved
checkout references draw the ring and the completed fill in the palette green,
and `action` is the navy reserved for primary buttons.

| Token | Value |
|---|---|
| `step-active-ring` | `#187C64` |
| `step-active-number` | `#187C64` |
| `step-complete-fill` | `#187C64` |
| `step-complete-content` | `#FFFFFF` |
| `step-connector-done` | `#187C64` |
| `step-inactive-number` | `#1B1B1B` |
| `step-connector-dot` | `#3E4945` at approximately `0.45` |
| `step-label` | `#1B1B1B` |
| `step-label-active` | `#187C64` |

An upcoming circle takes the standard glass fill; only the ring, the fill, the
number/check, and the label carry step state.

---

## 11. Semantic states

| State | Token |
|---|---|
| Success | `#187C64` |
| Warning | `#9A6700` |
| Error | `#BA1A1A` |
| Information | `#3F5774` |

These colors modify semantic state indicators only. Component geometry and glass behavior remain unchanged.

---

## 12. Font mapping

- English: Plus Jakarta Sans
- Arabic: Dubai
- Kurdish: current system fallback until the intended Kurdish font is bundled
- Approved onboarding/display exception: Unbounded where already intentionally used

Typography sizes/weights come from `DESIGN_SYSTEM.md`.
