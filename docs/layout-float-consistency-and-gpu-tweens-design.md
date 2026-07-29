# Layout float-consistency + GPU-driven motion — design, grounded in #46/#50/#51/#52

Status: design proposal, not implemented. Written per direct
instruction, after reading `docs/vfx-effect-primitives-taxonomy.md`
(`#46`) and `#50`/`#52` in full — this is their continuation, not a
new direction invented in isolation. Both real findings below came
from direct inspection this session, not assumption.

## Finding 1: the layout DSL has two incompatible numeric conventions, verified directly

`src/layout.lisp`:

```
(declaim (ftype (function (fixnum fixnum fixnum fixnum) list) centered-row-positions))
(declaim (ftype (function (fixnum fixnum fixnum fixnum) fixnum) lrp))
(declaim (ftype (function (fixnum fixnum fixnum fixnum fixnum fixnum) (values fixnum fixnum)) center-within))
(declaim (ftype (function (... single-float single-float single-float single-float single-float) (values single-float single-float)) anchor-at-edge))
```

`src/arena.lisp`'s own storage is already, consistently
`single-float` (`pos-x`/`pos-y`/`vel-x`/`vel-y`/`spawn-times`, all
`sf-vector` — `single-float` element type). raylib's own draw
primitives take floats throughout. So three of `layout.lisp`'s own
four primitive families (`centered-row-positions`, `lrp`,
`center-within`) use `fixnum`, while the fourth (`anchor-at-edge`) and
every other piece of this engine's own coordinate-consuming
infrastructure (the arena, tweens, raylib itself) use `single-float`.
This is the same boundary-mismatch bug class `#32`'s own
`define-timed-struct` was built to make impossible to write, at the
coordinate-type layer instead of the time-value layer.

**Direction, confirmed directly: unify on `single-float` throughout.**
Matches the arena, matches raylib, matches `anchor-at-edge` (already
the newer of the two conventions, and the one every recent addition —
`grid-origin`, the shader-cache work — already assumed). `fixnum`
buys nothing here; pixel-grid-looking values from `centered-row-
positions`/`lrp`/`center-within` still need to reach raylib as floats
eventually, so today's convention just moves the coercion to every
call site instead of fixing it once at the source.

### Scope of the fix
Retype `centered-row-positions`/`lrp`/`center-within`'s own `ftype`
declarations and bodies to `single-float`, audit every `deflayout
:grid`/`:row` consumer across all four games for a caller now passing
a raw integer where a `single-float` is required (the exact class of
break `#32`'s Rego rule and macro gate exist to catch during this
retrofit itself — run the gate after, not just before). A mechanical,
bounded retrofit once identified, not a redesign.

## Finding 2: the GPU-tween question, and why the answer isn't a flat yes or no

Direct question: since the arena/tween data is already
`single-float`-consistent and CPU-side genuinely only needs identity
+ start/end/time, why not let a shader do the interpolation?

**Checked directly, not assumed either way:**

`draw-card-face` (`src/cards/render.lisp`) uses plain immediate-mode
raylib calls (`draw-rectangle-rounded`, `draw-rectangle-rounded-
lines`, `draw-glyph-text`) — no custom shader at all, unlike `draw-
cell`/`draw-tile`/`draw-chrome-rect`, which already use the HSV
shader infrastructure. A naive per-card position shader would be a
**new** `begin-shader-mode`/`end-shader-mode` dispatch per card, not
folded into an already-happening pass.

And `#52` already found, independently, exactly the failure mode
that naive approach would reproduce: Queens' own `draw-cell` toggles
shader mode *inside itself*, once per cell — up to 144 toggles per
frame on a 12x12 board, "the CPU/GPU synchronization spike pattern"
`#52` names directly, with its own fix scoped as "instanced rendering
or a single full-grid shader pass taking per-cell state via a uniform
array/texture... a real rewrite, not a trivial fix." A per-card tween
shader on Hearts' own hand/trick would be the *identical* anti-
pattern at smaller scale (at most ~13 cards, not 144 cells, so the
cost is real but far smaller) — worth naming honestly rather than
recommending the same mistake `#52` already flagged as wrong.

**So: not "shader vs. no shader" — "batched shader vs. per-element
shader."** A single shader pass driving *all* currently-animating
cards' positions via a uniform array (or a texture-encoded position
buffer, matching `#52`'s own suggested direction for Queens) is the
version worth building — genuinely near-free relative to today's CPU
math once the dispatch is shared across every animating card in one
draw call, rather than one dispatch per card. This is real, valuable
GPU-offload; a naive per-card version is not — it trades cheap CPU
math for a worse-scaling GPU dispatch pattern, `#52`'s own finding
applied one level up.

### Why `VALUE-TWEEN` (`#46`'s own, not-yet-built generalization) is the right vehicle for this, not a new mechanism

`#46`'s own taxonomy already specced generalizing `TWEEN` from a
hardcoded 2D-position struct to a generic `VALUE-TWEEN` (N-
dimensional, easing-pluggable) — designed for scale/rotation/alpha,
not originally framed as a GPU question, but the same generalization
is what makes a batched shader pass practical: a uniform array of
`(start, end, start-time, duration)` tuples across all live tweens is
naturally expressible once tweens are a generic, array-friendly
value shape, not a position-specific struct tracked in a per-card
hash table. Building `VALUE-TWEEN` first (already scoped in `#46`,
not new scope invented here) and the batched-shader path second is
the right order — the second genuinely depends on the first's own
shape, not just conveniently follows it.

### CPU-mode fallback, per `#46`'s own standing rule
Every GPU-driven effect needs its CPU-mode equivalent designed
alongside it from the start (`#10`'s own already-found gap, restated
as a standing rule in `#46`). The batched-shader tween path's own
fallback is simply today's existing CPU math (`tween-position`,
already correct, already tested) — genuinely free as a fallback since
it's not new code, just the existing path kept as the `:cpu` render-
mode branch.

## Sequencing, and why this needed the event bus first

Per direct confirmation: this shader-first direction has been raised
several times, blocked on the event bus being real (now true — the
`:semantic` topic/`process-semantic-events` reconciliation this
session) and on this float-consistency question (this doc). Both
prerequisites are now either done or specified. Concrete order:

1. **Float-consistency retrofit** (Finding 1) — small, mechanical,
   bounded, and a real prerequisite: a batched shader pass needs
   consistent `single-float` throughout the values it's fed, not a
   mix requiring per-call-site coercion.
2. **`VALUE-TWEEN`** (`#46`'s own spec, not re-designed here) — the
   generic interpolation shape.
3. **Batched card-position shader**, Hearts' own hand/trick as the
   first real, bounded consumer (at most ~13 concurrent tweens, not
   144) — proven there before considering Queens' own, already-named,
   larger-scale shader-batching fix (`#52`), which is real but a
   bigger, separate rewrite.

Not proposing all three land in one pass — Finding 1 is genuinely
separable and should land first on its own, verified, before either
of the other two are touched.
