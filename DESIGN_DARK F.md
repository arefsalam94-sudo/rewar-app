| `step-complete-fill` | `#2AF598` |
| `step-complete-content` | `#00391E` |
| `step-connector-done` | `#2AF598` |
# DESIGN_DARK.md
## Lush Horizon: Moonlit — Dark Theme Tokens

**Role:** Theme-specific values only.  
**Structure and behavior:** Defined by `DESIGN_SYSTEM.md`.  
**Rule:** Do not redefine geometry, blur, radii, component behavior, or spacing here.

---

## 1. Core palette

| Token | Value |
|---|---|
| `surface` | `#101415` |
| `surface-dim` | `#101415` |
| `surface-bright` | `#363A3B` |
| `surface-container-lowest` | `#0B0F10` |
| `surface-container-low` | `#191C1E` |
| `surface-container` | `#1D2022` |
| `surface-container-high` | `#272A2C` |
| `surface-container-highest` | `#323537` |
| `on-surface` | `#FFFFFF` |
| `on-surface-variant` | `#FFFFFF` |
| `outline` | `#FFFFFF` |
| `outline-variant` | `#D5DDD7` |
| `primary` | `#D0FFDC` |
| `on-primary` | `#00391E` |
| `primary-container` | `#2AF598` |
| `on-primary-container` | `#006C3F` |
| `action` | `#2AF598` |
| `on-action` | `#00391E` |
| `secondary` | `#AACCD4` |
| `on-secondary` | `#12353B` |
| `tertiary` | `#E3F8F7` |
| `on-tertiary` | `#213434` |
| `error` | `#FFB4AB` |
| `on-error` | `#690005` |
| `error-container` | `#93000A` |
| `on-error-container` | `#FFDAD6` |

---

## 2. Background

| Token | Value |
|---|---|
| `background-gradient-top` | `#0C1F1F` |
| `background-gradient-bottom` | `#062C32` |
| `background-gradient-opacity` | `0.45` |
| `background-photo-blur-sigma` | `2` |

The opacity and blur values are identical to Light mode. Dark mode must **not** add stronger photo blur or a heavier gradient overlay.

Every screen must use a developer-supplied background photograph.

---

## 3. Liquid-glass theme tint

The base glass material comes from `DESIGN_SYSTEM.md`.

Dark-specific tint tokens:

| Token | Value |
|---|---|
| `glass-tint` | `#0C1F1F` |
| `glass-tint-opacity` | `0.06` |
| `glass-edge` | white/light neutral |
| `glass-shadow-color` | `#000000` |
| `glass-shadow-opacity` | `0.14` |
| `glass-inner-shadow-color` | `#000000` |
| `glass-inner-shadow-opacity` | `0.14` |

Do not use the dark emerald background gradient as an opaque card fill.

The glass must remain clear enough for the background image to be visible through it.

---

## 4. Selection and focus

| Token | Value |
|---|---|
| `selection-accent` | `#2AF598` |
| `selection-tint` | `#2AF598` |
| `selection-tint-opacity` | `0.16` |
| `selection-stroke-opacity` | `0.90` |
| `selection-stroke-width` | `1.5px` |
| `focus-accent` | `#2AF598` |

### Unselected

- lightly theme-tinted liquid glass
- no accent selection stroke
- only the neutral glass edge is present

### Selected / focused

- same liquid-glass structure
- stronger translucent Luminous Mint tint
- `#2AF598` accent stroke
- background remains visible through the control

Do not turn ordinary selected glass controls into fully opaque mint blocks.

---

## 5. Primary and secondary actions

### Primary action

- fill: `#2AF598`
- text/icon: `#00391E`
- geometry comes from `DESIGN_SYSTEM.md`

### Secondary action

Use the Dark liquid-glass material.

Do not create a separate opaque secondary-button style.

---

## 6. Text roles

| Role | Value |
|---|---|
| `text-heading` | `#FFFFFF` at `1.00` |
| `text-body` | `#FFFFFF` at `1.00` |
| `text-secondary` | `#FFFFFF` at `0.75` |
| `text-hint` | `#FFFFFF` at `0.60` |
| `text-link` | `#2AF598` at `1.00` |
| `text-on-action` | `#00391E` |
| `text-on-glass` | `#FFFFFF` |
| `text-disabled` | `#FFFFFF` at reduced emphasis |
| `text-error` | `#FFB4AB` |

### Usage

- headings must never look dim
- body text stays fully readable
- helper/subtitle text uses the secondary opacity
- placeholders use the hint opacity
- links/actions use Luminous Mint
- dark text is reserved for bright action fills such as the primary button

Do not use dark surface colors as text.

---

## 7. Icon colors

| Role | Value |
|---|---|
| `icon-accent` | `#2AF598` |
| `icon-feature-ring` | `#2AF598` |
| `icon-on-action` | `#00391E` |
| `icon-selected` | `#2AF598` |

Feature/category icons remain stroke-only circles with no fill.

---

## 8. Bottom navigation

| Token | Value |
|---|---|
| `nav-active-fill` | `#2AF598` |
| `nav-active-icon` | `#00391E` |
| `nav-inactive-icon` | `#FFFFFF` |
| `nav-label` | `#FFFFFF` |

The bar itself uses the shared liquid-glass material with exactly the same blur/opacity structure as Light mode.

---

## 9. Rating badges

Preserve the approved screenshot structure.

### Numeric score and star badge

| Token | Value |
|---|---|
| `rating-fill` | `#00391E` at approximately `0.88` |
| `rating-content` | `#2AF598` |
| `rating-accent` | `#2AF598` |
| `rating-stroke` | `#2AF598` at low opacity |

Keep score and stars visually clear, compact, and high contrast.

Do not use a bright solid mint badge unless a future approved reference explicitly changes the rating language.

---

## 10. Step indicator

Tokens for the multi-step flow indicator (`DESIGN_SYSTEM.md` section 14).

Step state is drawn in `primary-container`, which in Dark is the same Luminous
Mint as `action` — the distinction matters in Light, and the token names stay
one-for-one across both files.

| Token | Value |
|---|---|
| `step-active-ring` | `#2AF598` |
| `step-active-number` | `#2AF598` |
| `step-complete-fill` | `#2AF598` |
| `step-complete-content` | `#00391E` |
| `step-connector-done` | `#2AF598` |
| `step-inactive-number` | `#FFFFFF` at `1.00` |
| `step-connector-dot` | `#FFFFFF` at `0.45` |
| `step-label` | `#FFFFFF` at `1.00` |
| `step-label-active` | `#2AF598` |

An upcoming circle takes the standard glass fill; only the ring, the fill, the
number/check, and the label carry step state.

---

## 11. Semantic states

| State | Token |
|---|---|
| Success | `#2AF598` |
| Warning | `#FFD166` |
| Error | `#FFB4AB` |
| Information | `#AACCD4` |

These colors modify semantic state indicators only. Component geometry and glass behavior remain unchanged.

---

## 12. Font mapping

- English: Plus Jakarta Sans
- Arabic: Dubai
- Kurdish: current system fallback until the intended Kurdish font is bundled
- Approved onboarding/display exception: Unbounded where already intentionally used

Typography sizes/weights come from `DESIGN_SYSTEM.md`.
