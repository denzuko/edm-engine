# unifiedspec.org reference

Indexed from the actual `tokens.json` (denzuko/unifiedspec, fetched via
the GitHub API in full — not reconstructed from git history or partial
fetches). Read this before touching palette/typography/spacing in this
engine. Built after several real correction cycles on the theme work
that this reference would have prevented if it had existed first —
same lesson as `docs/qlot-guide.md`.

## The four lineages

unifiedspec.org's full description: "Design tokens for the Unified
Design System v1.0. Four lineages: Solarized (tonal palette),
Okabe-Ito (CVD-safe semantics), Plan 9/Acme (structure), Solaris/CDE
(chrome)."

- **Solarized** (Ethan Schoonover, 2011) — the tonal background/text
  palette, light and dark. CIELAB-calibrated, 16 colors.
- **Okabe-Ito** (2002) — colorblind-safe semantic colors (primary,
  success, warning, danger, info, special). Already used in this
  engine for Wordle's tile states — correctly, that part was never
  wrong.
- **Plan 9/Acme** (Rob Pike, Bell Labs 1992) — structural conventions:
  tag bars, selection fill, 0px chrome radius.
- **Solaris/CDE** (Sun Microsystems, 1993/2008) — the chrome/titlebar
  teal (`#008080`) this engine's `+theme-hue+` now derives from.

## Layer 0: raw palette (never reference directly in component code)

### Solarized

| Token | Hex | Role |
|---|---|---|
| `base03` | `#002b36` | Dark background |
| `base02` | `#073642` | Dark panel surface |
| `base01` | `#586e75` | Emphasis (dark) / body text (light) |
| `base00` | `#657b83` | Body text (dark) / emphasis (light) |
| `base0` | `#839496` | Body text default |
| `base1` | `#93a1a1` | Body text, dark mode (5.61:1 on base03) |
| `base2` | `#eee8d5` | Light panel surface |
| `base3` | `#fdf6e3` | Light background |
| `yellow`/`orange`/`red`/`magenta`/`violet`/`blue`/`cyan`/`green` | — | Syntax highlighting roles |

### Okabe-Ito

| Token | Hex | Role |
|---|---|---|
| `blue` | `#0072b2` | Primary actions (light) |
| `skyblue` | `#56b4e9` | Info / primary (dark) |
| `green` | `#009e73` | Success |
| `orange` | `#e69f00` | Warning/caution |
| `vermillion` | `#d55e00` | Danger/error |
| `pink` | `#cc79a7` | Special/beta |
| `yellow` | `#f0e442` | Supplementary only — fails tritanopia at small sizes |

(This engine's `+okabe-ito-orange+`/`+okabe-ito-bluish-green+`/
`+okabe-ito-sky-blue+` in `src/palette.lisp` use the *2008* Okabe-Ito
values, not these 2002 ones — close but not identical; Wordle's tile
colors were sourced separately and haven't been reconciled against
this file. Worth doing if that ever matters.)

### Plan9

| Token | Hex | Role |
|---|---|---|
| `body` | `#ffffea` | Acme window body |
| `tag` | `#eaffff` | Acme tag bar |
| `sel` | `#9eeeee` | Selection/focus fill |
| `scroll` | `#aaaaaa` | Worm strip (light) |

### Solaris/CDE

| Token | Hex | Role |
|---|---|---|
| `teal` | `#008080` | CDE titlebar — **this engine's `+theme-hue+` source** |
| `teal-dk` | `#005555` | CDE titlebar border |
| `orange` | `#d04000` | Sun logo block |
| `motif-gray` | `#c0c0c0` | Motif panel |
| `motif-lt` | `#e8e8e8` | Motif highlight |

## Layer 1: semantic tokens (what component code should reference)

### Background

| Token | Resolves to | Notes |
|---|---|---|
| `background.base` | `solarized.base3` (light) / `base03` (dark) | Content area — **this is `:dim` in this engine's `theme-hsv`** |
| `background.surface` | `solarized.base2` | Panels, sidebar — **this is `:panel`** |
| `background.titlebar` | `solaris-cde.teal` | App chrome — **this is `:accent`** |
| `background.tag` | `#eafaff` | Acme tag bar, P9+Solarized blend — not used in this engine yet |
| `background.sel` | `plan9.sel` | Selection/focus fill — not used in this engine yet |
| `background.code` | `solarized.base02` | Code block surface — not used in this engine yet |

### Foreground

| Token | Resolves to | Notes |
|---|---|---|
| `foreground.head` | `solarized.base03` | Headings, 13.92:1 on light bg |
| `foreground.body` | `solarized.base01` | Body text, 4.99:1 light / base1 5.61:1 dark |
| `foreground.muted` | `solarized.base00` | Secondary text — **this is `:muted`** |
| `foreground.faint` | `solarized.base1` | Decorative/disabled, 2.79:1 (intentionally low) |
| `foreground.on-dark` | `solarized.base3` | Text on dark surfaces (titlebar, dark card heads) |

This engine's `:info` role (dark high-contrast text on light bg)
maps most closely to `foreground.head`/`foreground.body`, not a
literal unifiedspec token name — there's no exact 1:1 mapping for
this engine's 5-role system (`:dim`/`:panel`/`:muted`/`:accent`/
`:info`) against unifiedspec's finer-grained token set. That's fine —
this engine is a simplified, single-hue-driven subset, not a full
reimplementation of every token.

### Semantic (state) colors — same as Okabe-Ito above, aliased

`primary`→blue/skyblue, `success`→green, `warning`→orange,
`danger`→vermillion, `info`→skyblue, `special`→pink.

### Border

`default` `#999999`, `light` `#cccccc`, `tag` `#b8d8d8`,
`titlebar` → `solaris-cde.teal-dk`.

## Typography

Two-register system — **already bundled in this engine**
(`assets/fonts/`, `ensure-ui-font`/`ensure-mono-font` in
`src/render.lisp`):

- **UI/display**: Titillium Web (fallback: Helvetica Neue, Arial,
  sans-serif) — headings, labels, buttons.
- **Mono/technical**: Inconsolata (fallback: Courier New, monospace)
  — code, tag bars, tokens, paths. This engine has `ensure-mono-font`
  loaded but **no `draw-mono-text` wrapper yet** — not used anywhere.
  Build one if a screen needs the technical register specifically
  (a Yahtzee dice-roll log? a Hearts trick history? — no current
  consumer, don't build blind).

### Font sizes (rem, base 16px — this engine uses px directly, no rem conversion layer)

| Token | rem | px equiv | Role |
|---|---|---|---|
| `xs` | 0.625rem | 10px | Overlines, badge text |
| `sm` | 0.6875rem | 11px | Nav labels, meta text |
| `base` | 0.8125rem | 13px | Body, code, inputs |
| `md` | 0.875rem | 14px | UI body, table cells |
| `lg` | 1rem | 16px | Labels, component headers |
| `xl` | 1.25rem | 20px | Subsection titles |
| `2xl` | 1.75rem | 28px | Section headings |
| `3xl` | 2.25rem | 36px | Page headings |
| `4xl` | ~3.25rem | 52px | Display/hero — **this engine's title screen uses 72px, larger than even this; a deliberate "arcade title" choice, not a token mismatch to fix** |

## Spacing (4px base unit — already in `src/render.lisp` as `+space-1+` through `+space-8+`)

| Token | px | Role |
|---|---|---|
| 1 | 4px | Icon/glyph gaps, badge padding |
| 2 | 8px | Tight element groups |
| 3 | 12px | Cell padding, tag-bar items |
| 4 | 16px | Component internal padding |
| 5 | 24px | Card/panel padding |
| 6 | 32px | Between component groups |
| 7 | 48px | Major section gaps, page padding |
| 8 | 64px | Page-level separation |

## Border radius — split register (already in `src/render.lisp`, but as *fractions*, see note)

unifiedspec's actual values are **absolute pixels**: `zero`=0px
(chrome: titlebars, tag bars, badges, Motif buttons, code blocks),
`sm`=2px (table rows, input borders), `md`=4px (solid buttons,
dropdowns), `lg`=6px (content cards, stat panels).

**This engine's `+radius-sm+`/`+radius-md+`/`+radius-lg+` are
fractional (0.03/0.06/0.1), not pixel values** — raylib's
`draw-rectangle-rounded` takes roundness as a fraction of the shape's
shorter side, not an absolute pixel radius, so a direct px value
can't be used the same way. This is a necessary adaptation, not a
bug — but it also means these constants don't have a literal
correspondence to unifiedspec's actual scale, and aren't currently
wired into any draw call (defined, unused — check before assuming
they're applied anywhere).

## Breakpoints (not applicable — this engine has no responsive layout)

768px/1024px/1280px — for `@media` queries in a real web GUI. This
engine renders at a fixed 800x700 window. Not relevant unless
window-resizing is ever added.

## What this engine has NOT yet reconciled against this file

- Wordle's Okabe-Ito tile colors were sourced from the 2008 palette
  revision, not the 2002 values in this file — close but not
  byte-identical. Not urgent (both are colorblind-safe), but a real
  discrepancy if anyone goes looking for exact hex matches.
- No `background.tag`/`background.sel`/`background.code` equivalents
  exist anywhere in this engine — no current UI element needs a tag
  bar, a text-selection highlight, or a code block.
- `border.default`/`border.light`/`border.tag` have no direct
  equivalent — this engine's borders are all `theme-color :accent`
  or `:muted`, not unifiedspec's separate gray border scale.
- No `draw-mono-text` wrapper exists despite `ensure-mono-font`
  being loaded — build it when something actually needs the
  technical register, not speculatively.
