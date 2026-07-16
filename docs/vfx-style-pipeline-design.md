# VFX/GFX/UI/theming architecture — game-pack-overridable style pipeline

Status: design proposal, not implemented. Written per direct instruction
to architect this before any code changes. Synthesizes and extends
several already-designed or already-audited pieces of this engine
rather than proposing a disconnected new system — see cross-references
throughout.

## Layered architecture

```
Game logic (GAME-UPDATE)
    | pushes semantic events -- never calls draw functions directly
    v
CHANL event bus (:vfx topic -- bus.lisp, currently dormant; #21/#22's
    | restoration is the prerequisite for this being real, not scaffolded)
    | producers can be any thread; the bus itself is thread-safe
    v
VFX processor -- runs once per frame, MAIN THREAD ONLY (raylib/GL
    | constraint, established repeatedly this session -- see #35)
    | drains the topic, instantiates/updates live effect instances
    | effect instances live in the arena (arena.lisp, #33 -- dormant
    | since the first commit; this is the real second consumer)
    v
Resolved style table -- O(1) lookup, computed once at load/theme-change,
    | never re-resolved per frame
    | selector -> flat attribute plist (cascade already resolved)
    v
Render primitives (draw-chrome-rect, draw-card-face, c-mera shader
    | uniforms via SET-SHADER-FLOAT/INT, already correct)
    v
Raylib / GPU
```

The governing discipline: cascade/style resolution is rare and can be
"expensive" (a few hash-table merges at load time); everything that
runs every frame is O(1) lookups, arena iteration via the already-
verified TRANSDUCERS pipeline, and draw calls. Nothing per-frame should
walk a cascade or re-parse a stylesheet.

## 1. Stylesheet DSL

S-expressions, not JSON -- this is a Lisp engine, and S-expressions let
the DSL be macro-processed (validated at compile time) rather than
parsed as a separate runtime data format. The selector vocabulary
reuses the existing theme-color role concept (`:dim`/`:panel`/`:muted`/
`:accent`/`:info` -- `src/palette.lisp`, already the established token
system) instead of inventing a parallel one.

```lisp
(defstylesheet :core
  (:selector (:card :back)
    :fill (:role :panel)
    :border (:role :accent)
    :radius (:space 1))
  (:selector (:dice :pip)
    :fill (:role :info))
  (:selector (:hearts :ai-avatar)
    :glyph-color (:role :accent)))
```

A game pack overrides by declaring the same selectors in its own
`defstylesheet`, in its own ASDF system, loaded after core -- no core
file edited:

```lisp
(defstylesheet :my-pack
  (:selector (:card :back)
    :fill (:role :accent)
    :radius (:space 3)))
```

### Macro-time validation (extends #32's precedent, doesn't duplicate it)

`DEFSTYLESHEET` checks attribute values at macro-expansion time: `(:role
:accent)` must name a real member of `(:dim :panel :muted :accent
:info)`; `(:space 1)` must resolve to one of `+SPACE-1+`..`+SPACE-8+`.
A bare pixel literal where a token is expected (`(:fill 55)`) is a
compile error, not a runtime surprise or a style-guide violation caught
in review -- same principle #32 proposes for the float-precision class
of bug, applied to style tokens.

### Cascade: last-loaded-wins, deliberately not full CSS specificity

No combinators, no specificity weighting -- this genre (tabletop/card/
puzzle/token games, a handful of screens, a handful of selectors) does
not need it, and building real CSS cascade semantics would be solving a
problem this engine doesn't have. Resolution happens once, at pack-load
or theme-change time (points that already exist -- `*theme-direction*`/
`*render-mode*` changes today), producing a flat hash table. If real
rule-precedence/conflict resolution between multiple packs is ever
needed beyond "last wins," that is exactly the shape #8's Datalog
branch was scoped for (facts + queries, not search) -- not a reason to
hand-rebuild specificity logic now. Not proposing that dependency
until last-wins genuinely stops being enough.

## 2. Layout system -- extends #36, does not re-litigate it

#36 (`docs/layout-dsl-design.md`) already designed the primitives this
genre needs, grounded in real duplication found across all four
shipped games: `CENTERED-GRID-POSITIONS`, `CENTER-WITHIN`,
`LINEAR-ROW-POSITION`. This section is additive:

- **Relative/anchor positioning**: Hearts' `AI-ORIGIN-POSITION` (anchor
  to a container edge, centered on the cross-axis) is the concrete
  existing case, currently Hearts-specific hand-written code. Generalize
  it into the shared layout vocabulary, per #36's own open question,
  rather than leaving every future "opponents around a table" game to
  reinvent it.
- **Aspect-ratio / genre-specific shapes**: exactly three, not a general
  constraint solver -- card fans (a hand, arc or overlap layout), grid
  puzzles (`CENTERED-GRID-POSITIONS`'s job, already scoped), and
  centered modal dialogs (the difficulty screen, the pause popup).
  Scoping to precisely these three is deliberate.

## 3. VFX pipeline

### Effects generalize TWEEN.LISP, and fix #31 as part of that, not after it

Today `TWEEN` is one concrete struct. The real shape underneath is a
protocol, matching `game-protocol.lisp`'s established style (generic
functions, default methods where sensible):

```lisp
(defgeneric effect-update (effect now))
(defgeneric effect-finished-p (effect now))
(defgeneric effect-apply (effect))   ; position offset, shake magnitude, particle draw
```

Card-flip tweens, camera shake, and particle bursts all implement this
instead of being three unrelated ad hoc systems each reinventing
timing. `TWEEN` becomes the first concrete implementation, with
`DOUBLE-FLOAT` throughout its time-valued slots from the start --
closing #31 as part of the generalization, not carrying the bug into a
second file the way it was originally missed the first time.

### Where instances live: the arena, not a fresh ad hoc list

`arena.lisp` -- generational-index storage, safe despawn (verified:
double-despawn is a no-op), correct stale-handle rejection after slot
reuse (verified via inspection this session, #33). Its own docstring:
"entity slots are recycled via generation-checked handles" -- exactly
what a pool of frequently-spawned/despawned VFX instances needs. It has
had zero real consumers since the very first commit (#33's finding).
This is the actual second consumer that justifies the system existing,
not a speculative future one.

### Triggering: events, never direct draw calls

```lisp
;; anywhere with bus access -- GAME-UPDATE, an AI-decision thread, etc.
(bus-push *engine-bus* :vfx (list :card-flip card leader-handle))
```

### The consumer -- corrected from a generic "threaded consumer" framing, and this matters

The bus itself (`chanl`) is genuinely thread-safe; producers can be any
thread. But raylib's GL context is thread-affine (established
repeatedly this session -- most concretely #35's e2e-suite
investigation, where cross-thread X11/input coordination is the leading
suspect for a real, live-verified test failure). So: **draining the
`:vfx` topic and instantiating/updating arena-backed effects happens on
the main thread only**, once per frame, as a new phase between
`GAME-UPDATE` and `GAME-RENDER` -- `BUS-TRY-POP` in a loop until empty,
spawn/update arena entries, then rendering pulls live handles via the
already-correct `ARENA-LIVE-HANDLES` transducer pipeline. Workers
*produce* events from wherever they run; only the render thread
*consumes* them into GPU-touching state. Not a generic thread pool
touching graphics state from multiple threads.

## 4. Style attributes -> shader parameters

No new binding mechanism -- extend what the chrome and cell shaders
already do (verified sound this session: zero drift regenerating all
five GLSL files from their c-mera source). A resolved style attribute
like `:shader-param (:hue 0.5)` maps directly onto the existing
`SET-SHADER-FLOAT`/`SET-SHADER-INT` calls (`render.lisp`) against
whatever uniform locations a c-mera-generated shader exposes. The style
system's job is producing values; the uniform-binding pipeline already
correctly gets them onto the GPU. This wires two already-sound systems
together rather than inventing a third path to the GPU.

## Constraints, addressed explicitly

- **Performance**: cascade resolution is load-time; VFX instances are
  arena-backed (contiguous storage, no allocation after init, already
  verified); per-frame style access is hash-table reads. The only new
  recurring cost is draining a bounded channel until empty, which is
  exactly what it exists for.
- **Maintainability / idiomatic style**: `DEFGENERIC`/`DEFSTRUCT`
  (matching `game-protocol.lisp`), macro-time validation (matching
  #32), the transducers pipeline (matching `ARENA-LIVE-HANDLES`,
  already correct), the chanl bus (matching `bus.lisp`, already
  correct). Nothing here is a new paradigm for this codebase -- it
  connects already-sound, already-audited pieces that have been sitting
  unconnected since early commits.
- **Game packs override without touching core**: ASDF system boundary
  plus load-order-is-cascade-order, the same shape `src/games/*/`
  already uses to add a table without editing `main.lisp`.

## Cross-references

Extends #36 (layout), depends on #21/#22 (CSP restoration -- the bus
needs to be real before this is real, not scaffolded), gives #33's
arena system its actual second consumer, folds in #31's fix rather than
deferring it, and notes where #8's Datalog branch would matter if
cascade resolution ever needs to be more than last-wins.

## Open questions, not resolved here

- Exact `DEFSTYLESHEET`/selector macro syntax -- sketched, not final;
  should be proven against one real retrofit (Hearts' AI-avatar
  glyph-color, or Queens' cell fill) before being treated as settled,
  same discipline as #36.
- Whether particle *simulation* math (not the draw call) is heavy
  enough to warrant an `lparallel` worker computing positions ahead of
  the main thread's consume phase, mirroring #22's audio-pregeneration
  design -- no current effect type is expensive enough to need this;
  revisit once a real particle system exists and is measured, not
  before.
- Whether `EFFECT-APPLY` should be allowed to enqueue further events
  (an effect finishing triggers a sound, e.g.) -- probably yes, via the
  same bus, but not designed in detail here.

Not implemented. This is the architecture and the reasoning connecting
it to what already exists; scoping a first real PR (which effect type,
which game pack, which selectors) is the next step once this direction
is confirmed.
