# Layout system & DSL — architecture proposal

Status: design proposal, not implemented. Written per direct instruction
to document and architect this before any code changes. Grounded in
what the four shipped games actually do today, not invented speculatively
— every pattern below was extracted from real, current source.

## Problem, with evidence

`src/layout.lisp` already has two genuinely reusable primitives:
`CENTERED-ROW-POSITIONS` (N evenly-spaced items centered in a container,
one axis) and `WRAP-TEXT-LINES` (greedy word-wrap to a width budget).
Both are well-designed, pure, and tested. Neither is used where the same
math is needed elsewhere.

**`CENTERED-ROW-POSITIONS` has exactly one caller in the whole
codebase** (`main.lisp`'s difficulty-selection screen). Queens and
Wordle each independently reimplement the identical "N items, fixed
size, fixed gap, centered in a container" math for their own grids —
different variable names, same formula, two separate places it can
drift out of sync:

```lisp
;; queens/render.lisp
(let ((total (+ (* size +cell-size+) (* (1- size) +cell-gap+))))
  ...)
;; wordle/render.lisp
(let* ((total-w (+ (* cols +tile-size+) (* (1- cols) +tile-gap+)))
       (total-h (+ (* rows +tile-size+) (* (1- rows) +tile-gap+))))
  ...)
```

**The identical "center text within a cell" formula appears three
separate times** in just these two files — Queens' mark label, Queens'
queen glyph, Wordle's letter tile:

```lisp
(round (+ x (/ (- +cell-size+ tw) 2.0)))
(round (+ y (/ (- +cell-size+ font-size) 2.0)))
```

Byte-for-byte the same shape, written independently three times, no
shared function.

**Hearts hand-computes a third recurring shape** — a fixed-offset
linear row, not centered, just `base + i*(size+gap)`:
```lisp
(defun hand-card-x (i) (+ 20 (* i 55)))
```
Yahtzee's dice row is the same shape again, inlined rather than even
given its own named function:
```lisp
(draw-die (+ 20 (* i 70)) 90 v h ...)
```

**unifiedspec's spacing scale (`+SPACE-1+` through `+SPACE-8+`) and
radius scale (`+RADIUS-SM+`/`+RADIUS-MD+`/`+RADIUS-LG+`) exist but are
used almost nowhere** — spacing only in `main.lisp`/`render.lisp`
themselves (tracked in #11), radius in zero draw calls anywhere
(tracked in #13). Every game's actual layout is raw pixel literals
(`20`, `55`, `62.0`, `90`), not the established scale.

**The window is now a fixed 1024×768** (no resize support) — every
position is computed against literal window-width/window-height
parameters passed around by hand, not derived from a layout tree that
could someday support different sizes without per-game rewrites.

## Design principles

1. **Extend `layout.lisp`'s existing primitives, don't replace them.**
   `CENTERED-ROW-POSITIONS` and `WRAP-TEXT-LINES` are sound. The gap is
   adoption (#-pattern already established this session — build a
   primitive, it doesn't get reused) and missing 2D/text-centering
   siblings, not a design flaw in what's there.
2. **Spacing and radius values come from the unifiedspec scale, not
   raw literals** — and per the established interest in macro-time
   enforcement (the float-precision gate proposal, #32), this should be
   a property of the DSL's macro expansion, not a style convention
   someone has to remember. A layout form that tries to splice in a bare
   pixel number where a spacing value is expected should fail to
   compile, not silently work.
3. **Declarative container/anchor composition, not per-screen
   arithmetic.** The recurring shapes found above — centered grid,
   linear row, center-within, and (from Hearts' AI-origin table)
   anchor-relative-to-container-edge — should be expressible as
   composed declarations, with actual pixel math computed once, in one
   place, not re-derived per screen.
4. **Doesn't touch card/tile/dice rendering itself.** This is about the
   surrounding position math (where does a row of items start, where
   does a cell's label center), not the established visual language for
   any individual element (real card shapes, pip-faced dice — those
   stay exactly as they are).
5. **Small, incremental adoption path.** Retrofitting all four games at
   once is out of scope for a first version — this should land as a
   library first, proven against one real consumer (likely Queens or
   Wordle, since they have the clearest duplication), before a broader
   retrofit pass.

## Proposed primitives (draft — for discussion, not final)

Extending `layout.lisp`:

```lisp
;; 2D sibling of CENTERED-ROW-POSITIONS — the Queens/Wordle grid case
(declaim (ftype (function (fixnum fixnum fixnum fixnum fixnum fixnum fixnum)
                          (values list list))
                centered-grid-positions))
(defun centered-grid-positions (rows cols item-w item-h gap-x gap-y container-w container-h)
  "Returns (values row-origins col-origins) — the same centering math
CENTERED-ROW-POSITIONS already does, per axis, composed rather than
reimplemented.")

;; the three-times-duplicated text-centering formula, named once
(declaim (ftype (function (fixnum fixnum fixnum fixnum fixnum) (values fixnum fixnum))
                center-within))
(defun center-within (container-x container-y container-w container-h content-w content-h)
  "Top-left position to center a CONTENT-W x CONTENT-H element within a
CONTAINER-W x CONTAINER-H region at CONTAINER-X,CONTAINER-Y.")

;; the Hearts hand-card-x / Yahtzee dice-row shape, named once
(declaim (ftype (function (fixnum fixnum fixnum fixnum) fixnum) linear-row-position))
(defun linear-row-position (base-offset index item-size gap)
  "BASE-OFFSET + INDEX * (ITEM-SIZE + GAP) — a fixed-start row, the
non-centered sibling of CENTERED-ROW-POSITIONS.")
```

A macro layer on top, for declaring a screen's layout as data rather
than a sequence of arithmetic — sketched, not committed to this exact
syntax:

```lisp
(deflayout hearts-hand (window-width window-height cards)
  (row :anchor (:left (- window-height +space-6+))
       :item-size +card-width+ :gap +space-2+
       :items cards))
```

The macro-time enforcement angle: `:gap`/spacing arguments would need
to resolve to one of the `+SPACE-N+` constants at macro-expansion time
(a `member`-style check against the known spacing symbols, not a
runtime type check) — a bare literal like `55` in a gap position would
be a compile error, not a style nit caught in review.

## What this closes

- The three duplicated centering/text-centering implementations found
  above, once Queens/Wordle are retrofitted (not in v1's scope, but the
  motivating case).
- #11 (unifiedspec typography/spacing never reached any game screen) —
  a real consumer for the spacing scale beyond the title/menu.
- #13's unused radius constants — a natural place for them to actually
  get wired in (cell/tile backgrounds, currently hard 0-radius
  rectangles).
- Indirectly, #18 (arcade-state's one-cursor-per-screen pattern) —
  not the same problem, but the same underlying theme of "ad hoc
  per-screen state/math instead of a shared structure," worth keeping
  in mind if both get addressed in the same pass.

## Open questions, not resolved here

- Exact macro syntax — the sketch above is illustrative, not a
  commitment. Should be refined against Queens' or Wordle's actual
  retrofit as the first real test, not designed in the abstract further
  than this.
- `AI-ORIGIN-POSITION`-style anchor-to-container-edge positions
  (Hearts' 3-AI-opponents-around-a-table arrangement): resolved yes,
  general — `ANCHOR-AT-EDGE` (#36), proven against Hearts' own real
  retrofit.
- Font-register selection (UI vs. mono vs. glyph) as part of a
  `(text ...)` declaration: resolved to stay purely positional,
  leaving font choice to the caller — decided directly, not left
  speculative. DEFLAYOUT's own shapes (:ROW/:GRID/:ANCHOR) return
  positions; carrying a font-register keyword through them would
  either couple this core, raylib-free system to render-level font
  accessors (breaking the same core/render separation +SPACE-N+'s own
  move to LAYOUT.LISP was made to preserve) or add a second,
  data-only "font keyword" indirection whose only real payoff was
  closing #11 "structurally" — a nice-to-have, not something #36's
  own positioning scope actually needs to be complete. #11 keeps its
  own, separate scope for typography/spacing reaching game screens.

Implemented (#36): DEFLAYOUT (src/layout.lisp) with :ROW/:GRID/:ANCHOR
shapes, macro-time :GAP enforcement, and a real retrofit across all
four games (Queens' QUEENS-CELL-POSITION, Wordle's WORDLE-CELL-
POSITION, Hearts' HAND-CARD-X and three AI-ORIGIN-N functions,
Yahtzee's DICE-ROW-X) — not left as a design statement alone.
