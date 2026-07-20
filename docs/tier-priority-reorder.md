# Tier priority, corrected: force-multiplier and dependency chain before simplicity

Status: standing reordering, written per direct correction — a real,
accurate observation that core rearchitecture work (#36, #37, #33,
#46) has been getting partial proofs without closure, while easier,
narrower work (process fixes, individual bug fixes, e2e coverage)
kept taking precedence turn to turn. This document is the corrected
priority, chosen by tracing actual dependencies rather than picking
whatever's most tractable next.

## The pattern being corrected

Tier 3's core architecture issues each got "prove one real consumer"
treatment and then sat open while attention moved to the next thing:
#36 (Queens + Wordle retrofit, no declarative macro layer), #37
(stylesheet DSL on Hearts, effect-state on Queens, event-triggered on
Yahtzee's confetti — three real proofs, no macro syntax, not closed),
#33 (confetti gave it a first real consumer, issue still open), #46
(two taxonomy categories implemented, most of the taxonomy untouched).
Each proof was real and correctly verified — the miss was not
returning to finish what each proof was a prerequisite for.

## The actual dependency chain, traced directly from the design docs

`docs/vfx-style-pipeline-design.md` states directly (not inferred):
named positions/sizes for event-triggered effects "resolve through
#36's layout system." #37 cannot be finished — as opposed to further
proven in isolated pieces — without #36's declarative layer existing
first. This is a real, structural dependency, checked directly in the
doc rather than assumed.

`docs/layout-dsl-design.md`'s own "open questions" section named its
prerequisite directly: exact macro syntax should be settled "against
Queens' or Wordle's actual retrofit as the first real test" — which
is now done (both retrofitted, #36's own primitives proven twice).
The blocker that kept the macro layer unwritten no longer exists.

Separately: #18 (`arcade-state`'s one-cursor-per-screen pattern) and
#19 (`GAME-UPDATE` missing window dimensions) are both named,
directly, as things #12 (room-of-tables), #39 (local multiplayer),
and #40 (AI characters) will make worse with each new screen/feature
if not addressed first. Building those Tier 4/5 features on the
current pattern means redoing the foundation later, under more
features already depending on it — the cost only grows with delay.

## The corrected order

1. **#36 — finish the declarative layout macro.** The root of the
   dependency chain: #37 cannot close without it, and #36's own stated
   blocker (a real retrofit to design against) is already satisfied.
   Highest leverage available right now, not the simplest available
   task.
2. **#37 — finish the effect-sequence macro layer**, now unblocked.
   Closes three already-proven-in-isolation primitives (stylesheet
   DSL, effect-state, event-triggered/arena) into the actual usable
   system the design doc describes, not three permanently-separate
   proofs.
3. **#18 + #19 — the foundational protocol gaps**, before any of #12/
   #39/#40 are attempted. Both are explicitly, directly named as
   blockers to those features scaling cleanly; fixing them first is
   the same "pay the cost once, early" logic as #36 → #37.
4. **#33 — close or explicitly downgrade.** Its own premise ("never
   had a real consumer") is no longer true — confetti is a real,
   live-verified consumer. Worth a real decision (closed, or
   re-scoped to "needs a *second* consumer to prove reusability"),
   not left open on a stale premise.
5. **#46 — continue the taxonomy**, now genuinely unblocked by #37's
   completed macro layer rather than needing another one-off proof
   each time.

## What this doesn't deprioritize

Process/discipline fixes (naming convention, test-layer separation,
fix-first) and real, reported bugs (#54's class of issue) still get
immediate attention when they come up — this reordering is about what
gets picked *proactively*, not about deferring things that are
actively broken or actively raised.

## Cross-references

Directly corrects the drift #36/#37/#33/#46 accumulated. Grounds the
new #36 → #37 → #18/#19 → #33 → #46 order in the design docs'
own stated dependencies, not a fresh guess.
