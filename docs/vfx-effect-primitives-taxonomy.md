# VFX effect primitive taxonomy — what's needed beyond tweens

Status: design proposal, not implemented. A catalog, per direct
instruction, organized by architectural shape rather than a flat list
-- each primitive is either a CPU-side value-driver (like tweens
already are) or a GPU/shader effect (like the chrome/cell shaders
already are), and that distinction matters for how each one gets
built, not just what it looks like.

## What's already real, checked directly rather than assumed

`TWEEN.LISP` has one hardcoded easing curve (`EASE-OUT-CUBIC`) driving
linear interpolation between two points -- a real, working primitive,
just not yet a *library* of curves. Queens' cell shader already has a
genuine oscillation effect (`0.5 + 0.5*sin(time*6)`, the cursor pulse)
-- a second, different motion shape from tween's point-A-to-point-B,
already proven in production. Both are the real foundation the
catalog below builds on, not a green field.

## Category 1: motion/timing primitives (CPU-side, drive existing draw calls)

These don't need new GPU work -- they're new *math shapes* feeding the
same kind of position/scale/alpha values tweens already produce.

- **Easing curve library** -- not a new primitive, a real gap in the
  existing one. `EASE-OUT-CUBIC` is hardcoded; bounce, elastic,
  ease-in, ease-in-out are the standard set most engines expose and
  this one currently doesn't. This is what "squash and stretch" mostly
  needs -- a scale-value tween using a bounce/elastic curve, not a
  separate effect system.
- **Oscillate/pulse** -- already real (Queens' cursor), worth
  generalizing explicitly as its own named category (periodic, not
  one-shot, not random) rather than leaving it Queens-specific
  shader code. A natural fit for highlighting an interactive element
  anywhere (a joinable seat in #39's flow, a discoverable-but-not-yet-
  examined cell in Labyrinth's fog-of-war).
- **Shake/jitter** -- genuinely different math from both tween and
  pulse: a random or noise-driven offset over time, not smooth
  interpolation and not periodic. Camera shake (already named in the
  original VFX brief) and Door Dasher's hazard-hit feedback are the
  two named real consumers.
- **Trails** -- a fading history of recent positions behind a fast-
  moving element. Relevant to Door Dasher's falling hazards and fast
  card-flip animations; a real particle-adjacent case, not fully new
  machinery once particles exist.

## Category 2: screen-space / post-process effects (GPU-driven, extend the c-mera shader pattern)

- **Blur** -- gaussian or box blur, screen-space or per-panel (a
  blurred background behind a modal dialog is the most likely first
  real consumer -- #38's widget system).
- **Bloom** -- bright regions bleeding light, the classic HDR-adjacent
  post-process effect. Lower priority than the others here -- this
  engine's flat, single-hue theme design doesn't currently produce the
  kind of bright/dark contrast bloom is built for; worth deferring
  until a real visual case calls for it rather than building it
  speculatively.
- **Vignette** -- darkened/desaturated screen edges. A real, named
  consumer: Labyrinth's fog-of-war atmosphere, and Door Dasher's
  tension-building as its countdown timer runs low.
- **Chromatic aberration** -- RGB channel split, typically an impact/
  damage feedback effect. Real consumer: Door Dasher hazard hits,
  Labyrinth combat hits.
- **Color grading / tint** -- broader than a simple color multiply
  (which "tint" alone often means) -- a real LUT-style palette shift
  for mood (a warning-red tint at low health/time, a desaturated tint
  for a specific table's atmosphere). Worth distinguishing a simple
  per-element tint (cheap, common) from full screen-space color
  grading (heavier, rarer) as two different costs, not one primitive.

## Category 3: per-object / localized effects (GPU-driven, smaller scope than full-screen)

- **Flash** -- a brief full-bright or full-color flash on an element,
  the simplest and most immediately useful of the named list. Real
  consumers everywhere collision/impact feedback matters: Door Dasher,
  Labyrinth combat, a correct Wordle guess.
- **Outline/glow (rim lighting)** -- highlighting a specific element's
  edge, distinct from bloom (screen-space bright areas) -- this is
  per-object. Real consumer: highlighting the cursor-selected item in
  any of #38's widgets, or a discoverable Labyrinth cell once adjacent
  but not yet entered.
- **Distortion / wave** -- localized UV displacement (heat-haze,
  water-ripple, a screen-wave radiating from an impact point). Real
  consumer: a Labyrinth dragon-encounter effect, or a Boss Monster
  room-destroyed effect.
- **Dissolve & erosion** -- noise-driven alpha-threshold reveal/hide,
  the "materializing" or "burning away" transition. Real consumer: a
  Labyrinth cell transitioning from fogged to discovered (dissolving
  the fog rather than an instant pop), or a defeated Boss Monster hero
  card dissolving away.

## Category 4: screen transitions (distinct from category 3's per-object effects)

- **Fade** -- already scoped concretely in #45 (title-to-menu alpha
  fade), the first real transition consumer.
- **Wipe / iris / pixelate** -- siblings to fade, not required for
  #45's first retrofit but worth naming now that a real transition
  need exists rather than treating fade as the only transition type
  this engine will ever need. Lower priority than fade specifically --
  #45 doesn't need them, a future table-to-table transition or a more
  stylized win/lose transition might.

## Category 5: celebratory/particle content (not a new system, specific content for the already-scoped particle case)

- **Confetti / celebration burst** -- the most likely first real
  particle-system consumer, not an abstract case. Direct consumer: #34
  once Yahtzee's `GAME-OUTCOME` is fixed, every table's win overlay is
  a natural home for this.

## Architectural note: CPU/GPU split matters here the same way it did for #10

Category 1 (motion/timing) is CPU-side math driving existing draw
calls -- no shader needed, no render-mode gap possible by construction.
Categories 2-4 are genuinely shader-driven, extending the c-mera
chrome/cell pattern -- and per #10's already-found gap (Wordle's tile
shader never got a CPU-mode fallback), **every one of these needs a
CPU-mode equivalent designed alongside it, not retrofitted after the
fact the way #10 had to be.** Worth stating as a standing rule for
whoever builds category 2-4 effects: a `*RENDER-MODE*` branch is part
of the effect's own definition, not a follow-up task.

## Cross-references

Extends #37's effect protocol (`EFFECT-UPDATE`/`EFFECT-FINISHED-P`/
`EFFECT-APPLY`) -- every primitive above is a concrete implementation
of that protocol, not a new one. Connects to #10 (CPU-mode discipline
for every shader-driven effect). Real named consumers drawn from #34
(win overlay/confetti), #38 (widget blur/glow), #39 (join-flow pulse),
#42 (Labyrinth fog-of-war dissolve/vignette, Boss Monster distortion),
#45 (Door Dasher shake/chromatic-aberration/flash, fade as the proven
transition case).

Not implemented. Flash, oscillate/pulse-generalized, and shake are the
cheapest to build first (CPU-side or trivial shader extensions of
already-proven patterns); bloom and full color-grading are the most
speculative and worth deferring until a real visual case calls for
them specifically.
