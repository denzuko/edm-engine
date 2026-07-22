# Tables/games as thin rule-base + event-generator modules — the bus-driven pattern applied systemically, not in three narrow spots

Status: real, honest architectural finding, not implemented. Written
per direct observation, checked against the actual codebase rather
than assumed.

## The observation, confirmed directly

The bus-driven, event-reactive pattern this session built for #37
(Yahtzee's confetti: `GAME-UPDATE` pushes `:vfx`, `GAMEOVERLAYEFFECTS`
drains it) and just extended for #58 (`ARCADE-SAVE-CURRENT` pushes
`:SAVE-GAME`, `PROCESS-SAVE-GAME-EVENTS` drains it) was never applied
systemically. Checked directly across the whole `src/` tree:

- **Audio**: all four games (`grep -rl "play-tone\|play-sound"
  src/games/*/render.lisp`) call `edm-engine/audio:play-tone`/
  `raylib:play-sound` directly, inline, from within their own
  `GAME-UPDATE` methods — not a single game pushes an audio-semantic
  event for a consumer to react to.
- **Rendering**: every game's own `GAME-RENDER` method calls
  `draw-*` functions directly and synchronously — the *entire*
  gameplay-content rendering pipeline (not just the VFX flourishes
  #37 covers) is direct-call, not event-driven.
- **`bus-push` call sites, whole codebase**: three. `:save-game`
  (#58), `:vfx` (#46/#37's confetti), and `:title-theme` — which
  #56 already found is a genuine dead producer, pushed but never
  drained anywhere. Three real, narrow spots, not a systemic pattern.

The layout DSL (`DEFLAYOUT`, #36) and the effect DSL (`DEFEFFECT-
STATE`/`DEFEFFECT-SEQUENCE`, #37) both exist and are real — but
neither is *reached via the bus*. A game currently calls
`HAND-CARD-X`/`QUEENS-CELL-POSITION` directly inside its own render
method, the same direct-call shape audio and pre-#37 VFX both had.

## The actual, honest scope of fixing this

This is not "finish one more consumer." It's restructuring every
game's own `GAME-UPDATE`/`GAME-RENDER` methods to push semantic events
(`:card-played`, `:dice-rolled`, `:cell-marked`, `:guess-submitted`,
`:turn-advanced`, `:game-won`, etc.) instead of calling audio/render
functions inline, and building the generic, shared consumers
(DSL-driven: a declarative mapping from semantic event to
tone/pattern for audio, to layout position for rendering, to effect
sequence for VFX) that drain those events — for all four games, not
one narrow slice.

## What this is not

Not a call to rewrite everything in one pass. The three real
consumers already built (confetti, save-game, and the two DSLs
themselves) are genuine, correct proof points for the pattern — the
gap is that "prove the pattern once" never became "apply the pattern
everywhere it belongs," the same shape of miss this session already
corrected twice for #36/#37's own scope (partial proofs treated as
done) and once for #9 (pieces documented away instead of finished).
This is that same correction, at the scale of the whole engine's own
architecture rather than one issue.

## Scope, for whoever picks this up

1. Design the semantic event vocabulary per game (what actually needs
   to be an event — likely not every single-frame state mutation, but
   the meaningful, player-facing transitions).
2. Design the audio DSL — a declarative event-to-tone/pattern mapping,
   replacing the four games' own scattered `play-tone` calls.
3. Extend the render side so `GAME-RENDER` genuinely composes
   `DEFLAYOUT`-declared positions and `DEFEFFECT-*`-declared effects
   reactively (via events), not just calls them as library functions
   from otherwise-direct-call render code.
4. Retrofit all four games as real consumers — not a design exercise
   proven against one, left there.
5. Resolve `:title-theme`'s own dead-producer status (#56) as part of
   this, not separately — it's the same category of gap.

Filed to track the real, full scope honestly, not to imply this is
close to done.
