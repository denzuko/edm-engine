# edm-engine

Pure Common Lisp game engine core. No C, no embedded ECL — the whole engine
is SBCL. `edm-engine` (core logic) has zero I/O dependencies; rendering
lives in `edm-engine/render` behind cl-raylib and is intentionally thin and
untested. Everything else is FiveAM-specified before implementation.

## Stack

- SBCL, `(optimize (speed 3) (safety 3))` on every hot-path file
- Qlot (`qlfile`) for dependency pinning when it works — has proven
  unreliable across environments; the Build section below has a
  plain-Quicklisp fallback that CI actually relies on
- `alexandria`, `serapeum` (`~>`/`~>>` threading, `defconstructor`, `op`)
- `transducers` for allocation-light entity query pipelines
- `chanl` for the topic bus, `lparallel` for parallel tick integration
- `cl-raylib` for rendering (render boundary only)
- `40ants-doc` for the manual (`docs/index.lisp`); no hand-duplicated prose
- FiveAM, run before any implementation line per the BDD gate

## Layout

```
src/package.lisp     package + exports, no logic
src/handle.lisp      generation-checked entity handle
src/bus.lisp         ChanL topic bus
src/arena.lisp       flat SoA component storage
src/ruleset.lisp     per-game rules-engine load/unload protocol (default no-op)
src/game-protocol.lisp  GAME-TITLE/UPDATE/RENDER/OUTCOME/SCORE/SAVE-DATA/STOP-AUDIO
src/ai-opponent.lisp AI-TIMER pacing + difficulty tiers, shared across AI-capable tables
src/tick.lisp         parallel physics integration + clock
src/tween.lisp        easing/tween engine (src/games/hearts uses it for card motion)
src/palette.lisp      monochromatic HSV theme system
src/arcade.lisp        menu/table-select/difficulty/save-load state machine (pure)
src/main.lisp          arcade I/O boundary — MAIN entry point
src/render.lisp         cl-raylib boundary — not unit-tested by design
src/cards/              deck/card primitives + card-shape rendering, shared across
                        any card game (Hearts is the first consumer, not the only one)
src/audio/              tone generation + tracker-style pattern/song sequencing
src/games/wordle/       Wordle table (pure logic + render)
src/games/queens/       Queens table — SCREAMER-based board generation + GPU cell shader
src/games/hearts/       Hearts table — trick-taking, 3 AI opponents
src/shaders/            shared GLSL generators (tools/hsv-shader-lib.lisp), chrome shader
assets/fonts/           bundled Unicode font (card suits, chess glyphs — raylib's default
                        font's coverage of these is unreliable)
t/*-spec.lisp           FiveAM specs, one per src file (render, package exempt)
t/games/*/*-spec.lisp   one suite per table
t/e2e/                  CLX+XTEST real-input integration tests (Xvfb, not headless-mock)
policy/gate.rego       OPA structural gate (not yet wired into CI — see CHANGELOG)
docs/index.lisp         40ants-doc manual
```

## Build

### Running the tests

Qlot pins dependency versions, but has proven unreliable across
environments — CI runs the plain-Quicklisp path below directly
(`.github/workflows/ci.yml`), and it's known to crash outright on some
SBCL/Roswell combinations. Try it first; fall back to plain Quicklisp
if it fails.

```sh
# via qlot, if it works in your environment
qlot install
qlot exec sbcl --non-interactive \
  --eval '(asdf:load-system :edm-engine/tests/all)' \
  --eval '(fiveam:run! :edm-engine)'

# plain Quicklisp fallback — this is what CI actually runs
sbcl --non-interactive \
  --load ~/quicklisp/setup.lisp \
  --eval '(push (truename ".") asdf:*central-registry*)' \
  --eval '(ql:register-local-projects)' \
  --eval '(ql:quickload :edm-engine/tests/all)' \
  --eval '(asdf:test-system :edm-engine/tests/all)'
```

`screamer` (used by Queens' board generation) isn't in base Quicklisp —
you'll also need Ultralisp:

```sh
sbcl --non-interactive --load ~/quicklisp/setup.lisp \
  --eval '(ql-dist:install-dist "http://dist.ultralisp.org/" :prompt nil)'
```

### Building the standalone executable

This is the step the README never actually documented — `qlot
install` alone doesn't produce a runnable game, and neither does
loading the test system.

```sh
sbcl --non-interactive \
  --load ~/quicklisp/setup.lisp \
  --eval '(push (truename ".") asdf:*central-registry*)' \
  --eval '(ql:register-local-projects)' \
  --eval '(ql:quickload :edm-engine)' \
  --eval '(asdf:make :edm-engine)'
```

Produces `./edm-engine`, a standalone ELF binary — `./edm-engine` to
run it directly, no SBCL or Quicklisp needed at runtime. Built assets
(shaders, the bundled font) resolve via `asdf:system-relative-pathname`
at build time, so the binary currently expects to run from within the
source tree it was built in — not yet relocatable to an arbitrary
install directory (tracked as part of the post-1.0 release pipeline,
issue #1).

For live debugging against a running instance: set
`EDM_ENGINE_SWANK_PORT=4005` before launching to start a SWANK server
(`swank-client` or Slime's `M-x slime-connect` both work), and
`edm-engine::*debug-arcade-state*` exposes the live arcade state for
inspection. Not started unless that env var is set — never active for
a real player.

## Multi-game direction

Board/card/dice/puzzle games plug into `ruleset-load`/`ruleset-unload`
(scene entry/exit hooks). Games needing genuine constraint satisfaction
(a Wordle-solver opponent, general ARG puzzle logic) get a `screamer`
engine populated on load and torn down on unload. Games that only need
corpus filtering (Wordle's own guess evaluation) use `transducers:filter`
directly and never touch the ruleset protocol.
