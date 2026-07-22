# All 40 open issues, checked against #59's own finding — which are real facets, which are genuinely independent

Status: honest audit, per direct instruction. Every issue's title and
body checked directly against #59's actual scope (the bus-driven,
thin-rule-base + event-generator + DSL-consumer pattern proven three
times but never applied systemically), not assumed related because
it sounds architectural.

## Direct facets of #59 — the same misalignment, named under a different number

- **#18** — `arcade-state`'s one-cursor-field-per-screen pattern won't
  scale. Same principle #59 names directly ("current loaded game is
  state, not namespace") — `arcade-state`'s own structure needs to
  support multiple concurrent consumers/screens the same way the bus
  needs to support multiple concurrent event topics, not one field per
  concern hardcoded in.
- **#21** — scoped CSP/channel usage for AI search and audio pre-
  synthesis. This *is* #59's own ask, named for two specific
  subsystems before #59 existed as a general finding.
- **#33** — the arena/ECS core "never had a real consumer across all
  four games." The identical shape of miss #59 names generally
  (confetti proved it works once; never applied to the other three
  games' own particle/animation needs).
- **#46** — VFX taxonomy, "what's needed beyond tweens." Directly the
  effect-DSL half of #59's own "DSL-driven consumers for GFX/VFX."
- **#56** — `:title-theme` bus event pushed, never drained. Literally
  cited inside #59's own body as one of the three real `bus-push`
  call sites in the whole codebase, and the one that's dead.
- **#10** — render-mode (GPU/CPU) toggle doesn't cover Wordle's tile
  shader. A real symptom of render logic being direct-call/per-game
  rather than systemically applied — the same shape as #59's own
  rendering-half finding, one level more specific.
- **#11** — typography/spacing (`draw-ui-text`, the spacing scale)
  never reached actual game screens. The layout DSL exists
  (`DEFLAYOUT`, #36) but isn't systemically applied — exactly #59's
  own "the DSL exists but isn't reached via the bus, called directly
  as a library function from otherwise-direct-call render code."
- **#43**'s undo-mechanism piece specifically (not the other two
  gaps in that issue) — real, event-sourced undo is a natural, much
  simpler consequence of a genuine event bus (replay/reverse semantic
  events) than it is to bolt onto the current direct-mutation
  architecture. Worth splitting out as its own #59-dependent piece
  rather than left inside #43's own, broader scope.

## Real dependents — need #59 addressed first to be built correctly, not themselves the architecture gap

- **#38** (widget/currency/inventory), **#39** (local multiplayer),
  **#40** (AI character/dialogue — dialogue reacting to game events is
  itself an #59-shaped need), **#42** (next-wave game paks), **#45**
  (Door Dasher) — all real, separate feature/content work, but each
  should be built using the corrected, systemic pattern from the
  start, not built direct-call and retrofitted later the way the
  existing four games were. Flagging the dependency, not folding
  these into #59 itself.
- **#12** (room-of-tables roadmap) depends on #18 directly (already
  known), and #18 is itself an #59 facet — so #12 depends on #59
  transitively too.
- **#50** (startup CPU usage) explicitly suspects "bus/thread
  offloading" as a cause — worth investigating with #59 in mind, not
  assumed unrelated.

## Genuinely independent — checked directly, not the same misalignment

`#1` (WASM release), `#3` (AI difficulty — likely already done),
`#5` (coin-flip libraries — future prep, real but separate), `#6`
(theme persistence — already reopened separately, a real gap but not
this one), `#7` (Serapeum/DRY audit), `#8` (Datalog/Prolog ruleset
branch — a different subsystem entirely), `#13` (VFX polish items —
Okabe-Ito version mismatch, unused constants — genuine bugs, not
architecture), `#14` (audio glitches — worth checking whether direct,
uncoordinated `play-tone` calls are the actual cause once #59's audio
piece lands, but not asserting that connection without evidence),
`#17` (CHANGELOG), `#19` (`GAME-UPDATE`'s missing window-dimension
parameter — a real protocol gap, but about a missing argument, not
event-driven dispatch), `#20` (BDD discipline — already substantially
addressed), `#25`/`#26` (CI/process), `#28`/`#29` (puzzle/gameplay
correctness, unrelated to dispatch architecture), `#32` (float-
precision mechanical gate — a different kind of systemic tooling
gap), `#41` (P2P, explicitly out of scope), `#44`/`#47` (roadmap/
principles docs), `#49` (title theme timing bug — different from
#56's dead-producer finding, a genuinely separate issue that happens
to touch the same feature), `#51`/`#52`/`#53`/`#55` (tooling/testing/
performance, real and separate), `#57` (CMDB headers, unrelated
finding).

## What this shows

Six issues (#10, #11, #18, #21, #33, #46, plus #56 and #43's undo
piece — eight facets total) are the *same* architectural gap #59
names, filed separately over the course of this session before the
pattern was named generally. Five more (#12, #38, #39, #40, #42, #45,
#50) are real, separate work that depends on #59 being addressed to
be built correctly rather than needing another retrofit later. The
other 27 are genuinely independent — checked directly, not assumed
unrelated to pad the count.
