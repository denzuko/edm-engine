# Orchestration DSL — Consfigurator's structural pattern applied to game orchestration, not each game's own subject matter

Status: design proposal, not implemented. Written per direct
instruction, following the same discipline #36/#37 were actually
built under: design doc first, narrow pilot second, migration only
after the pilot proves the force-multiplier claim against real code —
not a big-bang rewrite. Grounded in the four shipped games' own
current orchestration code, not invented speculatively.

## What this is not, stated first because it was almost gotten wrong

This is **not** "rewrite Hearts' trick-winner logic as Datalog facts."
Wordle's own shape makes that mistake visible immediately: it has a
ruleset (guess-feedback scoring, win/loss transitions) *and* a corpus
(word list) — but the corpus isn't part of the orchestration layer,
it's a resource the ruleset consults, the same way Hearts' scoring
table or Queens' board-adjacency structure are resources their own
rule functions consult. Modeling Wordle's corpus as DSL-level facts
would be forcing a bad domain fit onto a hammer, the exact anti-pattern
this session has been catching everywhere else.

**The actual scope: the DSL orchestrates the engine, not individual
games.** It describes how a table operates — turn sequencing, phase/
status transitions, event dispatch, bus wiring — as declarative
properties. Each game's own domain logic (`hearts/rules.lisp`'s
`legal-plays`, `trick-winner-index`; Wordle's corpus lookup; Queens'
board generation) stays exactly what it already is: plain, named,
directly-callable Lisp functions. The orchestration layer calls them,
the same way Consfigurator's own properties call arbitrary Lisp to do
their real work — the DSL is the composition/sequencing structure
around that work, not a replacement for the work itself.

## Constraint, non-negotiable: macro-expansion, not a runtime interpreter

A generic runtime engine walking S-expressions as data at execution
time — the naive reading of "Datalog/Prolog as the ruleset protocol"
(#8's original framing) — would be a real anti-pattern: an opaque
layer standing between the code and Lisp's own tooling. That is
explicitly not what's being proposed.

The already-proven precedent (`DEFAUDIO-CUES`, `DEFLAYOUT`,
`DEFSAVE-DATA`, and Consfigurator's own propapps) is a macro that
**expands at compile time into ordinary, named, traceable Lisp
function calls.** There is no separate runtime to debug through:
SWANK sees real functions, `TRACE` works normally, backtraces point at
real code, `40ants/docs` generates real documentation from real
docstrings on real `DEFUN`s the macro expanded into. Every debugging
tool already in daily use this session — SWANK, FiveAM, the condition
system, `40ants/docs` — already works, because the expanded form is
just more Lisp, not a new thing those tools need to learn.

This is the actual design constraint the whole proposal rests on, so
it's stated here as a hard requirement, not an implementation detail
to be decided later: **every orchestration form must macroexpand into
plain `DEFUN`/`DEFMETHOD`/`BUS-PUSH` calls, checkable with
`MACROEXPAND-1` at the REPL, never dispatched through a generic
S-expression walker at runtime.**

## The evidence: what orchestration already looks like, hand-rolled four times

All four games' own `game.lisp` share one shape, checked directly, not
assumed:

```lisp
;; hearts/game.lisp
(defstruct (hearts-game (:constructor %make-hearts-game))
  ...
  (phase :passing :type (member :passing :playing))
  (status :playing :type (member :playing :won :lost))
  ...)

;; queens/game.lisp
(defstruct (queens-game (:constructor %make-queens-game))
  ...
  (status :playing :type (member :playing :won))
  ...)

;; wordle/game.lisp
(defstruct (wordle-game (:constructor %make-wordle-game))
  ...
  (status :playing :type (member :playing :won :lost))
  ...)
```

Every game already has an explicit phase/status enum driving its own
orchestration — whose turn, what happens on a win/loss transition,
what's legal right now. Every game already hand-writes its own
version of "given current phase/status and an incoming action, what's
the next phase/status, and what events fire as a side effect" —
Hearts' `GAME-UPDATE` inline-checking `(round-over-p game)` then
calling `score-round`; Wordle's `TRY-SUBMIT` inline-checking status
before mutating it; Queens' own placement-then-win-check sequence.
**`DEFSAVE-DATA` (#58) already proved one axis of this exact
struct-to-declarative-macro conversion works** — this proposes doing
the same for the state-transition axis, not a new, unproven kind of
work.

## Design principles

1. **Orchestration, not domain logic.** The DSL describes phase/status
   transitions and the bus events each transition fires. It calls out
   to each game's own existing domain functions (`legal-plays`,
   `trick-winner-index`, Wordle's scoring, Queens' board queries) to
   decide *whether* a transition is legal — it doesn't reimplement
   those functions' own logic as DSL-level facts.
2. **Flattened namespace, one shared orchestration layer.** Not
   `src/games/hearts/orchestration.lisp` duplicated per game (the same
   `tools/generate-chrome-shader.lisp` vs `tools/generate-queens-
   shader.lisp` mistake this session already found and fixed) — one
   real, shared macro in `src/orchestration.lisp` (or similar,
   genuinely flattened location), each game a thin, declarative
   consumer.
3. **Bus-first, not bolted on after.** Every transition the DSL
   describes pushes its own semantic event (`:trick-won`,
   `:round-scored`, `:guess-submitted`) — directly composing with
   `edm-engine/audio:process-audio-events` and whatever #59's own
   rendering/layout bus consumers eventually become, not a second,
   parallel dispatch mechanism.
4. **Macro-expansion only** (see constraint above) — checkable,
   traceable, no runtime interpreter.
5. **Consfigurator's structural pattern, not its API.** Declarative
   properties, composed via combinators, applied to a target — the
   *shape*, reimplemented in edm-engine's own terms, not
   `(ql:quickload :consfigurator)` and its literal property functions.

## Proposed pilot: Hearts

Per the same discipline #36/#37 were built under — prove it against
one real consumer before generalizing. Hearts is the natural pilot:
its own `rules.lisp` is already pure, already declarative in spirit
(`legal-plays`, `trick-winner-index` take state, return answers, no
side effects), and its `game.lisp` orchestration
(`passing → playing`, trick-complete → score → next-trick-or-round-
over) is a real, non-trivial state machine worth proving the pattern
against — not a toy case.

**Pilot success criteria**, stated before implementation starts so
"done" has a real bar to clear, not a vague sense of progress:
- Hearts' orchestration expressed via the new macro, Hearts' own
  `rules.lisp` domain functions untouched and still directly called.
- `MACROEXPAND-1` on the new forms produces plain `DEFUN`s calling
  `BUS-PUSH`, confirmed directly, not assumed.
- All existing Hearts BDD/TDD specs still pass unmodified against the
  new orchestration (a behavior-preserving refactor, not a rewrite
  that happens to also change behavior).
- A genuine token-count comparison, old hand-written orchestration
  vs. new declarative form — the thesis this whole project is meant
  to be evidence for, measured, not assumed.

Only after the pilot clears those criteria does migrating Queens/
Wordle/Yahtzee, or reframing #18/#19/#33 under this architecture,
become the next real decision — not decided speculatively here.

## Relationship to other open issues

- **#8** (Datalog/Prolog as the ruleset protocol) — this proposal is
  the corrected, narrower reading of #8's own intent: Datalog-style
  declarative *description* of orchestration, not a runtime Datalog
  *engine* evaluating facts. #8 should be re-scoped or closed in favor
  of this doc once this direction is confirmed.
- **#18/#19** (arcade-state scaling, `GAME-UPDATE`'s missing window
  parameter) — likely reshaped by this architecture rather than fixed
  independently; held per the prior session's own sequencing decision
  until this doc's direction is confirmed.
- **#33** (arena/handle/tick ECS core) — same; its own "never a real
  consumer" question may resolve differently once orchestration has a
  real, shared consumer to evaluate it against.
- **#59** (systemic bus-driven architecture) — this DSL is the
  natural, declarative *authoring* layer for #59's own bus events, not
  a separate concern from it.
