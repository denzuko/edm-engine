# Fix it first: bugs found during BDD/TDD/e2e get fixed as part of that work, not filed and deferred

Status: standing rule, in force. Written after a real instance of not
doing this — #54 was filed first and treated as deferrable batch work,
when the actual right move (once pointed out directly) was to root-
cause and fix it immediately, since it was blocking legitimate
completion of the tier work already in progress.

## The rule

If a bug surfaces *during* the BDD → TDD → e2e cycle for work actually
being done right now — a spec that should pass doesn't, a live/visual
check reveals something wrong, an e2e run behaves unexpectedly — fix
it as part of that same work before moving on. Filing an issue and
deferring it is not a substitute for fixing it when it's discovered in
the course of doing the work the fix belongs to.

This is different from noticing something unrelated while doing other
work — that still gets filed normally (per #50/#51/#52's own
precedent: real findings, filed, not chased mid-stream on unrelated
work). The distinction is scope: is the bug part of what's being built
or verified right now, or a separate thing noticed in passing? The
former gets fixed now; the latter gets filed.

## Why this matters beyond process tidiness

A filed-but-deferred bug in the same area as new work means every
subsequent commit in that area is built on, and "verified" against, a
known-broken foundation — the verification itself becomes untrustworthy,
compounding rather than just delaying the problem. #54 was exactly
this: continuing tier work with a known rendering bug unfixed would
have meant every further visual retrofit's "live-verified" claim was
suspect from the start, the same credibility gap that made #54 worth
finding in the first place.

## What this doesn't mean

Not every bug gets dropped-everything treatment — a bug found in an
unrelated subsystem while doing something else is still a normal filed
issue, not an interruption. And "fix it first" doesn't mean skipping
the process (BDD gate, TDD correctness, e2e attestation) to patch
something fast — the fix still goes through that same discipline, just
without a deferred issue sitting in between discovery and resolution.

## Cross-references

Directly prompted by #54's own handling. Sits alongside
docs/naming-convention.md and docs/test-layer-separation.md as a third
standing correction this session made durable rather than left to be
restated.
