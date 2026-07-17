# SwiftStash Brand Book

Operational brand reference for anyone — human or AI agent — producing SwiftStash-branded material: README graphics, DocC pages, the example app, social previews, presentations. Every decision below is **approved and final**; do not alter the logo geometry, the accent colour, or the wordmark treatment without asking the maintainer first.

Source of truth for the visual compositions: the interactive brand book [SwiftStash Brand Book.html](SwiftStash%20Brand%20Book.html) in this directory; this file mirrors those decisions in plain text and carries the ready-to-use assets in [Assets/](Assets/).

## 1 · Logo

The SwiftStash mark is a **padlock between square brackets** — `[ 🔒 ]`. The brackets represent Swift code and a container (they literally enclose something, like a "stash"); the padlock represents the Keychain and secure storage. Together: *a secure stash in code*.

Canonical SVG (72 × 72 grid — this exact geometry, never redrawn):

```svg
<svg viewBox="0 0 72 72" fill="none">
  <path d="M20 10 L10 10 L10 62 L20 62" stroke="#F05138" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M52 10 L62 10 L62 62 L52 62" stroke="#F05138" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
  <rect x="26" y="33" width="20" height="16" rx="3" fill="#F05138"/>
  <path d="M31 33 v-5 a5 5 0 0 1 10 0 v5" stroke="#F2994A" stroke-width="4" fill="none"/>
</svg>
```

Rules:

- The brackets are **square brackets `[ ]`**, drawn as angle pieces — never braces `{ }`.
- The padlock is optically centred between the brackets, vertically and horizontally (body starts at y = 33 in the 72 × 72 grid).
- The only element that changes between variants is the shackle colour (and, on orange, the whole mark):

| Context | Brackets & body | Shackle | Ready asset |
|---|---|---|---|
| Dark background | `#F05138` | `#F2994A` (Amber) | [Assets/swiftstash-logo-dark.svg](Assets/swiftstash-logo-dark.svg) |
| Light background | `#F05138` | `#D13A22` (Rust) | [Assets/swiftstash-logo-light.svg](Assets/swiftstash-logo-light.svg) |
| Orange background | `#FFFFFF` | `#FFD9CF` | [Assets/swiftstash-logo-white.svg](Assets/swiftstash-logo-white.svg) |

## 2 · Wordmark & lockup

**SwiftStash** — one word, no space, set in the Apple system face (`-apple-system` / SF Pro Display / Segoe UI), weight **700**, negative letter-spacing (≈ −0.03 em).

- "Swift" is always white on dark backgrounds, or `#1C1E21` on light backgrounds.
- "Stash" is always **`#F05138`**.
- Never colour the whole word in one colour, and never split it into two words.

The full lockup is symbol + wordmark on one line, **spaced by roughly the width of one bracket**. Ready lockups: [Assets/swiftstash-lockup-dark.svg](Assets/swiftstash-lockup-dark.svg) (dark background — "Swift" `#FFFFFF`, shackle `#F2994A`) and [Assets/swiftstash-lockup-light.svg](Assets/swiftstash-lockup-light.svg) (light background — "Swift" `#1C1E21`, shackle `#D13A22`). These use SVG `<text>` with the system font stack, so exact letterforms depend on the viewing platform — for pixel-perfect output (e.g. a social preview PNG), rasterise on a platform where SF Pro is available (macOS).

## 3 · Colours

The primary accent is **`#F05138` — the official Swift orange**. This is a deliberate decision: the library is strictly Swift-only, so the colour gives instant identification with the language (it is the same shade used by the Swift badges in the README). Do not change it without asking.

| Name | Hex | Role |
|---|---|---|
| Swift Orange | `#F05138` | Primary accent; "Stash" in the wordmark; brackets and padlock body |
| Amber | `#F2994A` | Secondary accent on dark (padlock shackle, links) |
| Rust | `#D13A22` | Secondary accent on light (padlock shackle) |
| Ivory | `#F4F1EC` | Light background (warm ivory) |
| Ink | `#0D1117` | Dark background (also `#0B0E14` for page bodies) |
| Panel | `#12161F` | Code cards / panels on dark |
| Frame | `#3D4450` | Borders and edges (`#454D59` for frames on the GitHub social preview) |
| Text | `#C8D0D9` | Body text on dark |

Supporting greys: `#8B949E` and `#6B7684` for secondary/dimmed text on dark; `#232A36` for hairline borders on dark.

### Syntax highlighting (code on dark backgrounds)

| Token | Hex |
|---|---|
| Keyword / attribute (`@Stash`) | `#FF7AB2` |
| String literal | `#7EE787` |
| Type name | `#79C0FF` |
| Plain code text | `#C8D0D9` |
| Comment / dimmed | `#6B7684` |

## 4 · Typography

| Use | Stack | Notes |
|---|---|---|
| Brand, headings, body copy | `-apple-system, 'SF Pro Display', 'Segoe UI', sans-serif` | Headings weight 700 with negative tracking |
| Code, API chips, repository address | `ui-monospace, 'SF Mono', Menlo, monospace` | Wrapper names (`@Stash`, `@Stashed`, `@SecureStash`) are **always** set in monospace |

### API chips

The three wrappers are presented as pill-shaped chips: monospace weight 600, text `#FFB4A1`, background `rgba(240, 81, 56, 0.14)` (14 % accent), border `rgba(240, 81, 56, 0.4)` (40 % accent), border radius 8 px.

## 5 · GitHub social preview

- Format: exactly **1280 × 640 px** (2:1), PNG under 1 MB — GitHub's requirements; keep all content at least 40 px from the edges.
- Must read well in both GitHub light and dark mode: dark variants carry a 2 px light frame (`#454D59`); alternatively use the Ivory light background.
- Fixed content: wordmark + strapline "Type-safe UserDefaults & Keychain for Swift" + the three wrapper chips; optionally "Zero dependencies · Swift 6 ready · MIT".
- Any code shown on graphics must be **real code from the README** — never pseudocode.
- Layouts that work: a dark code card on the Ivory background, a dark composition inside the 2 px light frame, or central typography over dimmed code.

## 6 · DocC cards

Topic cards carry the brand into the documentation: bracket motif, Swift Orange accent, monospace API names.

- Format: **640 × 360 px SVG**, one light + one dark variant per topic, named with DocC's appearance convention — `card-<topic>.svg` (light) and `card-<topic>~dark.svg` — so each card follows the reader's appearance setting.
- New cards reuse the same grid: icon on the left, title + topic list on the right, bracket accent in Swift Orange.
- The full set (getting started, API reference, products, UserDefaults, SwiftUI, migrating, keychain, keychain configuration, crypto, helpers, logging — plus the architecture/products diagrams, lockup, and technology icons) lives in the repo at `Sources/SwiftStash/SwiftStash.docc/Resources/` (SwiftUI-module assets in `Sources/SwiftStashUI/SwiftStashUI.docc/Resources/`).
- The cards render on the published documentation site: **<https://tklocek.github.io/SwiftStash/documentation/>**.

## 7 · Asset inventory

| Asset | Path | Use |
|---|---|---|
| Logo, dark backgrounds | `Branding/Assets/swiftstash-logo-dark.svg` | READMEs, DocC, slides on dark |
| Logo, light backgrounds | `Branding/Assets/swiftstash-logo-light.svg` | Docs and pages on light |
| Logo, monochrome white | `Branding/Assets/swiftstash-logo-white.svg` | On Swift Orange or photographic backgrounds |
| Lockup (logo + wordmark), dark | `Branding/Assets/swiftstash-lockup-dark.svg` | README header on dark |
| Lockup (logo + wordmark), light | `Branding/Assets/swiftstash-lockup-light.svg` | README header on light |
| DocC topic cards, diagrams, icons (light + `~dark`) | `Sources/SwiftStash/SwiftStash.docc/Resources/`, `Sources/SwiftStashUI/SwiftStashUI.docc/Resources/` | DocC articles and landing pages — live at <https://tklocek.github.io/SwiftStash/documentation/> |
| Interactive brand book | `Branding/SwiftStash Brand Book.html` | Browsing the identity with live previews |

For GitHub READMEs, pair the dark/light assets with `<picture>` and `prefers-color-scheme` so the correct variant renders in each theme.

## 8 · Applying the brand

- **README** — badges already use Swift Orange (`F05138`) for Swift-related shields; keep that convention. A header may use the lockup SVGs with a `<picture>` element.
- **DocC** — the documentation site (built by `Scripts/build-docs.sh`, published at <https://tklocek.github.io/SwiftStash/documentation/>) is themed via `Sources/SwiftStash/SwiftStash.docc/theme-settings.json` (copied to the site root by the build script); the accent is Swift Orange `#F05138`, heroes use Ink/Ivory. Page cards, diagrams, and icons belong in each catalogue's `Resources/` directory and follow §6.
- **Example app** — any branding inside `Example/` uses the same palette and the canonical logo geometry.
- **Anything new** (banners, diagrams, slides) — dark surfaces use Ink/Panel with Frame borders, light surfaces use Ivory; accent stays Swift Orange; code snippets use the syntax palette above and must be real, compiling code.

## 9 · Rules for agents (summary)

1. Never redraw, restyle, or "improve" the logo — reuse the canonical SVG or the files in `Assets/`.
2. Never change the accent from `#F05138`, and never recolour the whole wordmark.
3. Wrapper names are always monospace; "Stash" in the wordmark is always Swift Orange.
4. Code on any graphic is real code from the README or documentation.
5. Social preview graphics keep the 1280 × 640 px format and the light/dark-mode safeguards.
6. DocC cards keep the 640 × 360 SVG format and always ship as a light + `~dark` pair.
7. When a decision is not covered here, match the nearest approved pattern and flag the gap to the maintainer rather than inventing a new one.
