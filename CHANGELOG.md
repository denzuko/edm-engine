# Changelog

## [Unreleased]
### Added
- 10-slot save/load: each slot independent (own `.sexp` + `.png`), with
  table title, score, save timestamp, and a screenshot. Save/Load screen
  browses all 10 with the same up/down convention as every other menu.
- Queens: full second table. Board/region generation via SCREAMER
  (`A-MEMBER-OF`/`ASSERT!`) — the first genuine constraint-engine use in
  this codebase, the reserved seam `edm-engine/ruleset` existed for.
  25-level campaign (4x4 through 8x8, 5 levels per size), each level
  seeded by its own level number. Real LinkedIn-Queens interaction
  (empty -> marked "X" -> queen -> empty, not a plain toggle); conflict
  detection per rule (row/column/region/adjacency) with red-highlighted
  feedback on the board. Queen glyph is U+265B (♛), not "Q"/"q".
- Monochromatic HSV theme system (`src/palette.lisp`): one hue drives
  chrome (menus, panels, backgrounds) via a GPU shader
  (`src/shaders/chrome.fs.lisp`), generated — not hand-typed — from a
  new shared generator (`tools/hsv-shader-lib.lisp`) that also drives
  Queens' cell shader (region hue + a real GPU-side cursor-glow pulse).
  Functional/accessibility-critical colors (Wordle's tile states)
  deliberately stay outside this system — see that shader's own
  docstring for why free hue-rotation is unsafe there.
- Tracker-style music engine (`src/audio/tracker.lisp`): note/pattern
  sequencing on top of the same `generate-samples` engine UI SFX already
  used, not a second audio system. Both tables now have a real composed,
  looping theme in the confirmed classic-puzzle-game genre — Queens in
  C major (I-V-vi-IV), Wordle in G major (I-vi-IV-V) — distinct
  progressions so the two tables don't sound interchangeable.
- CI actually tests the whole engine now (`edm-engine/tests/all`, 331
  checks across core/wordle/audio/queens), not just `edm-engine/core`;
  runs via a hand-rolled Quicklisp+Ultralisp bootstrap after
  `40ants/setup-lisp@v4` turned out to be broken on the runner.

### Fixed
- `raylib`'s default ESC-closes-window behavior was silently killing
  the whole arcade loop on the first pause-menu press — found via a
  real end-to-end input-driven walkthrough, not unit tests alone.
- A real audio bug only visible by building and running the actual
  compiled binary (not `sbcl --eval` against source): raylib/miniaudio
  failed to load generated WAV data whenever the audio device's
  negotiated sample rate didn't match this engine's hardcoded 44100Hz —
  traced to inconsistent test-environment PulseAudio sink setup, not
  the tested game logic.
- Three real SCREAMER bugs in Queens' board generation (nondeterministic-
  context violations with `DOTIMES`/`LABELS`, unbacktracked mutation),
  each found by actually running the constraint search, not by
  reasoning about the code.

### Known gaps
- Queens has no `:restore-fn` yet — doesn't support save/load resume.
- `policy/gate.rego` (OPA structural gate) exists but is not wired into
  CI — currently a file, not an enforced gate.
- No git tags yet; semver tagging hasn't started for this project.
- Native binary build + itch.io/WASM release pipeline: deferred to
  post-1.0 by design (tracked in GH issue #1), not started.

### Added (earlier foundation)
- `edm-engine`: pure-CL game engine core. Handle (generation-checked entity
  reference), Arena (flat SoA component storage, fixed capacity), Bus
  (ChanL topic-keyed pub/sub), Tick (LPARALLEL-parallel physics integration
  over a TRANSDUCERS-gathered live-handle set).
- `edm-engine/ruleset`: per-game rules-engine load/unload protocol, default
  no-op. Reserved seam for a SCREAMER-backed constraint engine when a
  genuine constraint-satisfaction game (not corpus-filter games like
  Wordle) is added.
- `edm-engine/render`: cl-raylib I/O boundary. Thin by design, no game
  logic, not unit-tested.
- `edm-engine/docs`: 40ants-doc manual over the public API.
- FiveAM spec suite (28 checks) covering everything except the render
  boundary and package declarations.
- `policy/gate.rego`: OPA structural gate — spec-per-source-file, CHANGELOG,
  LICENSE, per-file optimize declaims.
