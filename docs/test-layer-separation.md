# Test layer separation: BDD, TDD, and e2e are three distinct artifacts, not one file wearing different hats

Status: standing rule, in force. Written after a real, specific miss:
`t/effect-spec.lisp` was written as a genuine BDD gate (failed
honestly with `UNDEFINED-FUNCTION` before `pulseVal`/`ese` existed),
but once real bugs turned up, they were fixed by editing that *same*
file's expected values — meaning the file quietly switched from acting
as a BDD gate to acting as a TDD correctness-check, in place, without
that ever being a deliberate decision. The concern wasn't that bugs
got caught — that's the system working — it was rewriting a BDD unit
at all. Locking in the actual rule here so it doesn't happen again.

## The three layers, and what each one owns

**BDD — the goal gate.** States *what* the work is for, broadly, before
the work exists. Written first, expected to fail honestly
(`UNDEFINED-FUNCTION`, not a wrong assertion) until the implementation
makes it true. Once it passes, **it stays passing and stays largely
untouched** — a BDD spec is a durable statement of intent, not a
scratchpad for working out exact values. If a BDD assertion turns out
to need real revision, that's a deliberate, separate decision (the goal
itself changed), not a byproduct of debugging arithmetic.

**TDD — correctness of the implementation.** Precise, detailed,
allowed to be iterated on freely — exact arithmetic, edge cases,
independent-state checks, the kind of thing that's genuinely likely to
have a bug in its own first draft (as `effect-spec.lisp`'s base/
amplitude scaling and raw-oscillation checks both did). This is where
debugging expected values belongs, in a file whose whole job is
correctness-checking, not in the file whose job was proving the work
didn't exist yet.

**e2e / live verification — attestation in the running system.**
Unchanged from established practice (SWANK live checks, recorded
gameplay) — confirms the implementation behaves correctly in the
actual, running engine, not just in isolation.

## What this means concretely

Separate files (or, at minimum, a clearly separated section within a
suite, never the same test form reused across roles):

- `t/<subsystem>-spec.lisp` — BDD. Broad, goal-level assertions.
  "PULSEVAL produces a value that changes over time." "ESE returns a
  fresh, near-zero elapsed value immediately on activation, and NIL
  after deactivation." Not exact arithmetic — that's not this layer's
  job, and precision here is what invites rewriting it later.
- `t/<subsystem>-impl-spec.lisp` — TDD. Precise, detailed correctness.
  "PULSEVAL matches Queens' exact shader formula at t=0 and t=pi/12."
  "ESE tracks two independent keys without cross-contamination."
  Expected to need real debugging during first implementation — that's
  what this layer is *for*, and iterating here doesn't touch the BDD
  gate at all.

A BDD spec failing with `UNDEFINED-FUNCTION` before implementation
exists is correct and expected. A BDD spec's *assertion* being wrong
after implementation exists is a signal the assertion belonged in the
TDD layer to begin with, not a normal thing to patch in place.

## Scope: forward-applying, same as the naming convention

New work follows this split from here forward. `t/effect-spec.lisp`
is being restructured now as the first concrete example, precisely
because it's the file that prompted this rule — not a broader
retroactive pass across the rest of the existing test suite, which
stays as-is unless a file is already being touched for real work.

## Cross-references

Sharpens #20 a second time (the first sharpening established BDD as a
goal gate rather than a test written after the fact; this establishes
that the gate, once passed, is a distinct artifact from the
correctness-checking that follows it). Same "measured, documented,
locked into memory" discipline as `docs/naming-convention.md` — this
was raised once and is being made durable immediately, not left to be
raised a second time.
