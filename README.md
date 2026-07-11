# edm-engine

Pure Common Lisp game engine core. No C, no embedded ECL — the whole engine
is SBCL. `edm-engine` (core logic) has zero I/O dependencies; rendering
lives in `edm-engine/render` behind cl-raylib and is intentionally thin and
untested. Everything else is FiveAM-specified before implementation.

## Stack

- SBCL, `(optimize (speed 3) (safety 3))` on every hot-path file
- Qlot (`qlfile`) for reproducible dependency pinning
- `alexandria`, `serapeum` (`~>`/`~>>` threading, `defconstructor`, `op`)
- `transducers` for allocation-light entity query pipelines
- `chanl` for the topic bus, `lparallel` for parallel tick integration
- `cl-raylib` for rendering (render boundary only)
- `40ants-doc` for the manual (`docs/index.lisp`); no hand-duplicated prose
- FiveAM, run before any implementation line per the BDD gate

## Layout

```
src/package.lisp   package + exports, no logic
src/handle.lisp     generation-checked entity handle
src/bus.lisp        ChanL topic bus
src/arena.lisp       flat SoA component storage
src/ruleset.lisp    per-game rules-engine load/unload protocol (default no-op)
src/tick.lisp        parallel physics integration + clock
src/render.lisp      cl-raylib boundary — not unit-tested by design
t/*-spec.lisp        FiveAM specs, one per src file (render, package exempt)
policy/gate.rego    OPA structural gate
docs/index.lisp      40ants-doc manual
```

## Build

```sh
qlot install
qlot exec sbcl --non-interactive \
  --eval '(asdf:load-system :edm-engine/tests)' \
  --eval '(fiveam:run! :edm-engine)'
```

## Multi-game direction

Board/card/dice/puzzle games plug into `ruleset-load`/`ruleset-unload`
(scene entry/exit hooks). Games needing genuine constraint satisfaction
(a Wordle-solver opponent, general ARG puzzle logic) get a `screamer`
engine populated on load and torn down on unload. Games that only need
corpus filtering (Wordle's own guess evaluation) use `transducers:filter`
directly and never touch the ruleset protocol.
