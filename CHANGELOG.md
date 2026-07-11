# Changelog

## [Unreleased]
### Added
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
