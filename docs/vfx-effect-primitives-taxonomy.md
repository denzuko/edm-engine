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

**Correction, direct question prompted it**: zoom and rotation
exposed a real gap this taxonomy's first pass glossed over.
`TWEEN`'s struct (`start-x`/`start-y`/`end-x`/`end-y`) is hardcoded to
2D position specifically -- it does not generalize to scale, rotation
angle, or alpha (which #45's fade already needs) without either
duplicating the struct per value type or, correctly, making the
interpolated value itself generic:

```lisp
(defstruct value-tween
  (start-values nil :type (simple-array double-float (*)))  ; N-dimensional
  (end-values nil :type (simple-array double-float (*)))
  (start-time 0.0d0 :type double-float)
  (duration 0.0d0 :type double-float)   ; DOUBLE-FLOAT throughout, #31's lesson
  (easing #'ease-out-cubic))            ; pluggable, once the curve library exists
```

Position becomes a 2-dimensional instance; scale, rotation angle, and
alpha are 1-dimensional instances of the same primitive, not three more
structs. This is the actual shape #37's "generalize TWEEN via a real
protocol" should target -- generic over the interpolated value, not
just wrapped in a protocol while staying position-specific underneath.

- **Per-object zoom/scale** -- a `VALUE-TWEEN` on a scale factor. Real
  consumer: a card "punching in" on being played, a Door Dasher pickup
  growing before vanishing.
- **Per-object rotation** -- a `VALUE-TWEEN` on an angle. Real
  consumer: a card flip's actual rotation (currently likely faked via
  position/scale alone), a die tumbling mid-roll.
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
- **Trails** -- a fading history of recent positions behind a fast-
  moving element. Relevant to Door Dasher's falling hazards and fast
  card-flip animations; a real particle-adjacent case, not fully new
  machinery once particles exist.

## Category 1a: whole-screen camera effects -- genuinely new, verified available, corrects how "shake" should actually work

Checked directly: this engine has no camera concept anywhere today
(`grep` for `begin-mode-2d`/`camera2d` across `src/` returns nothing).
Every table draws directly in screen space. But `cl-raylib` genuinely
exports a real `Camera2D` (`MAKE-CAMERA2D`, `BEGIN-MODE-2D`) --
zoom/rotation/target/offset applied to an entire render pass, not a
per-draw-call parameter. Verified before designing around it, not
assumed.

**Correction to Category 1's original "shake" entry**: whole-screen
camera shake belongs here, not as per-draw-call jitter. Randomizing a
`Camera2D`'s offset each frame shakes everything drawn in one place,
correctly and cheaply; jittering every individual draw call's position
would mean every draw site needs to know a shake is active, which is
both more expensive and more error-prone. The math (random/noise-
driven offset over time) is the same shake primitive already named --
this corrects *where* it applies, not what it is.

- **Camera zoom** -- a `VALUE-TWEEN` on `Camera2D`'s zoom field. Real
  consumer: a dramatic zoom on a win moment (#34's fixed overlay), a
  zoom-in as Door Dasher's timer runs critically low.
- **Camera rotation** -- a `VALUE-TWEEN` on `Camera2D`'s rotation
  field. Lower-priority than zoom/shake -- no currently-named consumer
  needs a rotating camera specifically, worth having the primitive
  available rather than building content against it speculatively.
- **Camera shake** -- moved here from Category 1, corrected as above.

Introducing `Camera2D` as a real primitive is itself worth flagging as
new core-engine surface, not just new VFX content -- every table's
`GAME-RENDER` currently draws with no camera transform active at all;
wiring one in (even an identity/no-op `Camera2D` by default) is a small
but real prerequisite before any of category 1a's effects can exist.


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
- **Dissolve & erosion** -- specced precisely below (a three-phase
  HSV-space burn/dissolve, not the generic noise-threshold sketch an
  earlier draft of this entry left vague). Real consumer: a Labyrinth
  cell transitioning from fogged to discovered (dissolving the fog
  rather than an instant pop), a defeated Boss Monster hero card
  dissolving away, or a future block/row-clear mechanic modeled
  directly on this entry's own reference case.

### Dissolve shader, precisely specced -- modeled on Sega Genesis arcade Tetris's row-clear flash

Direct reference: the classic effect where a completed row flashes
(a bright, inverted "burn") then visibly dissolves before the rows
above drop to fill the gap -- not decoration, the actual mechanic that
told the player a line was clearing. Genuinely applicable beyond a
future Tetris-shaped table -- this project's assets are already
generic HSV monochromatic objects (the whole theme system is hue-
driven, `PALETTE.LISP`), so this is a primitive any graphic asset in
the pipeline can use via #45's effect-sequence DSL, not a Tetris-
specific effect that happens to be reusable.

**The exact math**, `tt` = `t/t_max` (normalized, matching #45's own
`RAW-TT` convention exactly):

- **`tt < 0.1`** ("burn mask"): the object's own texture color,
  converted to HSV, gets fully inverted -- hue shifted 180° (`+0.5`
  mod `1.0` in normalized hue space), saturation and value both
  `1.0 - x`. RGB tinting is bypassed entirely for this phase -- the
  shader samples the object's real texture and works in HSV space
  derived from it, not from any applied theme tint.
- **`0.1 <= tt < 0.2`**: the inversion mask is disabled -- HSV reverts
  to the sampled, unmodified value. A single brief strobe (invert, then
  immediately normal), not a repeating oscillation -- matching the
  precise two-window timing rather than a generic "flash effect."
- **`0.2 <= tt <= 1.0`**: `V` (the sampled/reverted value from the
  prior phase) has `tt` itself subtracted from it, clamped to `0.0` --
  progressively darkens as `tt` approaches `1.0`, reaching black
  regardless of the object's original brightness. This is the actual
  "dissolve" -- not an alpha fade, a value collapse in HSV space.
- **At `t_max` (+ one tick)**: the effect's own scope ends here --
  `EFFECT-FINISHED-P` (per #37's protocol) reports true, and whatever
  triggered the dissolve (a Tetris-shaped row-clear, a Boss Monster
  hero's defeat) proceeds with its own game-logic consequence (delete
  the tiles, drop the row) -- the shader's job is the visual, not the
  game-state mutation that follows it.

**Illustrative c-mera shader sketch** -- a genuine new requirement this
surfaces: no existing shader in this codebase converts RGB *to* HSV
(`TOOLS/HSV-SHADER-LIB.LISP` only generates the HSV*->*RGB direction,
`chrome.fs`/`cell.fs`'s whole job). This shader needs both directions,
since it samples a real texture rather than generating flat color from
uniforms the way the existing two shaders do -- worth flagging as new
shared shader-library surface, not just a new shader file:

```lisp
;; illustrative — not verified to compile via c-mera, a design sketch
;; matching this codebase's established shader syntax, same caveat
;; every DSL sketch in #37/#45 already carries
(decl ((in vec2 |fragTexCoord|)))
(decl ((uniform sampler2D texture0)))  ; the object's own sprite/tile
(decl ((uniform float tt)))            ; t/t_max, 0..1, from #45's tween
(decl ((out vec4 |finalColor|)))

;; new: RGB->HSV, the direction TOOLS/HSV-SHADER-LIB.LISP doesn't have yet
(function rgb-to-hsv ((vec3 c)) -> vec3 ...)

(function main nil -> void
  (decl ((vec4 tex (texture texture0 |fragTexCoord|))))
  (decl ((vec3 hsv (call rgb-to-hsv (: tex xyz)))))
  (if (< tt 0.1)
      (progn (set (: hsv x) (mod (+ (: hsv x) 0.5) 1.0))
             (set (: hsv y) (- 1.0 (: hsv y)))
             (set (: hsv z) (- 1.0 (: hsv z))))
      (if (>= tt 0.2)
          (set (: hsv z) (max 0.0 (- (: hsv z) tt)))))
      ;; 0.1 <= tt < 0.2: HSV stays as sampled, no branch needed
  (set |finalColor| (vec4 (call hsv-to-rgb hsv) (: tex w))))
```

**CPU-mode fallback, designed alongside the shader per #46's own
standing rule, not deferred**: the three-phase logic is pure per-pixel
math with no GPU-specific requirement -- a CPU-mode equivalent applies
the identical phase logic to a `Color` value directly (via raylib's
`ColorToHSV`/`ColorFromHSV`, matching the shader's RGB<->HSV round
trip) before drawing, rather than a shader pass. Same visual result,
different execution path, exactly the discipline this taxonomy already
commits to for every category 2-4 effect.

**DSL integration** -- the actual point of specifying this precisely,
per direct request: a named primitive #45's `DEFEFFECT-SEQUENCE`/
`DEFEFFECT-STATE` can reference by name, not a one-off shader bolted
onto a single table:

```lisp
;; illustrative — a row-clear effect chaining this primitive
(defeffect-sequence :row-cleared
  (:trigger :event :row-cleared)
  (:dissolve :target :cleared-row :duration (:space 4)))  ; t_max in
                                                            ; the shared
                                                            ; timing scale
```


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
of that protocol, not a new one. Corrects the tween generalization
itself to be value-generic (position/scale/rotation/alpha as instances
of one `VALUE-TWEEN`, not separate structs) rather than leaving it
position-specific. Introduces `Camera2D` as new, verified-available
core-engine surface (zoom/rotation/shake all route through it),
correcting where shake should apply rather than adding a new effect.
Connects to #10 (CPU-mode discipline
for every shader-driven effect). Real named consumers drawn from #34
(win overlay/confetti, now also camera zoom), #38 (widget blur/glow), #39 (join-flow pulse),
#42 (Labyrinth fog-of-war dissolve/vignette, Boss Monster distortion),
#45 (Door Dasher shake/chromatic-aberration/flash, fade as the proven
transition case). The dissolve shader spec surfaces a genuine new
requirement for `TOOLS/HSV-SHADER-LIB.LISP`: an RGB->HSV direction,
which doesn't exist yet (the library only generates HSV->RGB, all
`chrome.fs`/`cell.fs` have ever needed) -- worth scoping as shared
shader-library work before or alongside whoever builds this specific
effect, not duplicated per-shader if a second consumer needing the
same direction shows up.

Not implemented. Flash, oscillate/pulse-generalized, and shake are the
cheapest to build first (CPU-side or trivial shader extensions of
already-proven patterns); bloom and full color-grading are the most
speculative and worth deferring until a real visual case calls for
them specifically.
