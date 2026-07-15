# edm-engine

Pure Common Lisp game engine core. No C, no embedded ECL — the whole engine
is SBCL. `edm-engine` (core logic) has zero I/O dependencies; rendering
lives in `edm-engine/render` behind cl-raylib and is intentionally thin and
untested. Everything else is FiveAM-specified before implementation.

## Stack

- SBCL, `(optimize (speed 3) (safety 3))` on every hot-path file
- Qlot (`qlfile`/`qlfile.lock`) for reproducible dependency pinning —
  a package manager on top of Roswell's version management, not
  invoked by wrapping `sbcl`/`ros` inside it (see Build below)
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

Full qlot reference (qlfile syntax, all source types, the Ultralisp
project-naming gotcha, commands): [`docs/qlot-guide.md`](docs/qlot-guide.md).

Full unifiedspec.org design token reference (palette, typography,
spacing, radius — indexed from the real `tokens.json`, not
reconstructed piecemeal): [`docs/unifiedspec-guide.md`](docs/unifiedspec-guide.md).

### Running the tests

The mental model: `ros` is a version manager (like `nvm`) — it manages
which SBCL is active. `qlot` is a package manager (like `yarn`/`npm`)
— it manages project-local Lisp dependencies with a lock file. You
don't nest one through the other at runtime; `qlot install` sets up
`.qlot/` once, and `ros run` picks it up directly via `QUICKLISP_HOME`
— no `qlot exec` wrapper needed, and no need to repeat the env var on
every single command either. Set it once per shell session, same as
`nvm use`:

```sh
ros install sbcl-bin && ros use sbcl-bin   # version manager: pick the Lisp
ros install qlot                            # install the package manager
qlot install                                # package manager: resolve qlfile.lock

export QUICKLISP_HOME="$(pwd)/.qlot/"       # once per session — not per command
ros run --non-interactive \
  --eval '(push (truename ".") asdf:*central-registry*)' \
  --eval '(ql:quickload :edm-engine/tests/all)' \
  --eval '(asdf:test-system :edm-engine/tests/all)'
```

`QUICKLISP_HOME` needs the trailing slash — Roswell builds a pathname
from it via `make-pathname`, and without the slash it doesn't resolve
to `.qlot/setup.lisp` correctly. `screamer` (Queens' board generation
dependency, not in base Quicklisp) is declared via Ultralisp directly
in `qlfile`, so `qlot install` alone is fully reproducible — no
separate manual Ultralisp step needed with this path.

If `qlot install` itself fails on your machine (a real crash has been
seen — a fatal low-level SBCL fault inside Roswell's qlot subprocess
on a specific SBCL/Roswell combination, not reproducible on other
SBCL versions), plain Quicklisp is the fallback — it's also what CI
runs directly. This path isn't pinned by the qlfile, so it needs its
own explicit Ultralisp install for `screamer`:

```sh
sbcl --non-interactive \
  --load ~/quicklisp/setup.lisp \
  --eval '(push (truename ".") asdf:*central-registry*)' \
  --eval '(ql:register-local-projects)' \
  --eval '(ql-dist:install-dist "http://dist.ultralisp.org/" :prompt nil)' \
  --eval '(ql:quickload :edm-engine/tests/all)' \
  --eval '(asdf:test-system :edm-engine/tests/all)'
```

### Building the standalone executable

```sh
ros make-edm-engine.ros
```

That's it — `qlot install` first if you haven't already (above), then
this. Produces `./edm-engine`.

**Not named `build.ros`** — "build" collides with Roswell's own
reserved `build` subcommand (`ros build <script>` compiles a script
into a standalone executable). A script literally named `build.ros`
risks `ros build.ros` being parsed as invoking that subcommand instead
of running the script directly — which is what actually happened on a
real machine: instead of executing the script, Roswell compiled the
script itself into a frozen image and ran that, which crashed, because
the script's own logic was never meant to run as a pre-compiled image.
Renamed to remove the ambiguity outright.

Why not `ros build edm-engine.asd program` (Roswell's own generic
build command)? Tried it first — it doesn't work for this project.
Roswell's own build machinery loads a `.asd` file via a raw `CL:LOAD`,
which doesn't set up the package/reader context `DEFSYSTEM` needs —
that context only exists when ASDF loads a system properly (via
`FIND-SYSTEM`/`LOAD-SYSTEM`), not a bare `LOAD`. Confirmed by reading
Roswell's own `build-asd.lisp` and reproducing the exact failure
(`undefined function: DEFSYSTEM`) directly — not a project
misconfiguration, a real gap in `ros build` for multi-system project
`.asd` files like this one. `make-edm-engine.ros` (committed in this
repo) wraps the verified-working sequence — `ql:quickload` then
`asdf:make`, the two steps that actually need ASDF's proper loading
path — behind a simple one-command interface.

If you'd rather see the steps explicitly, or `make-edm-engine.ros`
doesn't work on your machine for some reason:

```sh
# via qlot (QUICKLISP_HOME already exported above)
ros run --non-interactive \
  --eval '(push (truename ".") asdf:*central-registry*)' \
  --eval '(ql:quickload :edm-engine)' \
  --eval '(asdf:make :edm-engine)'

# plain Quicklisp fallback
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
