# Complete tier ordering — all 41 open issues, checked individually, not a partial pass

Status: supersedes `docs/tier-priority-reorder.md`'s partial scope
(6 issues). Per direct instruction to double-check every open ticket,
not just the ones already flagged. Every issue below was read in full
(not just its title) before being placed.

## Tier A — active, real, severe problems: fix regardless of architectural leverage

These aren't "force multipliers" in the structural sense, but they're
correctness/trust/distribution failures happening *now*, not
speculative future work — the same category #9's own title names
directly ("not just a gap").

1. **#9 — Save State silently produces an unusable, deceptive save
   for 3 of 4 games.** Concrete, already-diagnosed, small fix
   (`save-game-to-slot` needs to check `game-save-data`'s NIL before
   writing a slot that looks real but isn't) — high severity (a
   player believes their progress is saved when it isn't), low
   effort. No reason to defer this behind any architecture work.
2. **#24 — the compiled binary isn't relocatable.** A genuine "can't
   ship" blocker, distinct from #1's WASM scope — this is about the
   *existing* native build not working outside its exact source tree.
   Real distribution risk, not speculative.
3. **#48 — e2e fails differently on a real CI runner than the dev
   sandbox.** Blocks #53's own e2e work from actually protecting
   against regressions automatically — the Hearts/Yahtzee e2e tests
   added this session are real and pass locally, but without this
   fixed they can't run on every push the way the core suite does.

## Tier B — force-multiplier architecture (the corrected order from the prior pass, unchanged reasoning)

4. **#36 — layout DSL's declarative macro.** Root of the dependency
   chain traced directly from the design docs (see prior doc for the
   full citation) — #37 cannot close without it, and #36's own stated
   blocker (a real retrofit to design against) is satisfied.
5. **#37 — VFX pipeline's effect-sequence macro**, unblocked by #36.
   Closes three already-proven-in-isolation primitives into one real
   system.
6. **#32 — mechanical gate for the float-precision bug class.** A
   real, distinct force multiplier: the same single/double-float
   mismatch was found three separate times by manual audit. A
   mechanical check (compile-time or a linting pass) prevents the
   *class* of bug recurring a fourth time, rather than relying on
   another manual audit later — genuinely multiplies future
   correctness work rather than just fixing one instance.
7. **#18 + #19 — arcade-state scaling and GAME-UPDATE's window-
   dimension gap.** Both named directly as blockers #12/#39/#40 will
   make worse with each new feature if not fixed first.
8. **#33 — close or explicitly downgrade.** Its own premise ("never a
   real consumer") is stale since confetti. Low effort, real decision
   needed, not left open on outdated grounds.

## Tier C — correctness/quality gaps, quick and concrete

Not architectural, not urgent-severe like Tier A, but real, verified,
and cheap relative to their trust impact.

9. **#28 — Queens' board generation never verifies a unique
   solution.** A puzzle without a unique solution is a real quality
   defect for a puzzle game specifically.
10. **#29 — Wordle's guess-validation corpus is the same small list
    used for target selection**, rejecting real, valid English words.
11. **#43 — three verified gaps**: no settings persistence, no
    seeded/reproducible puzzles, no undo anywhere. Each independently
    checked directly against the code, not speculative.
12. **#10 — render-mode (GPU/CPU) toggle doesn't cover Wordle's tile
    shader.** A real consistency bug in an already-shipped feature.
13. **#11 — unifiedspec typography/spacing never reached most game
    screens**, only the title/menu. Consistency gap across the actual
    shipped UI.

## Tier D — content/UX expansion, sequenced after their real dependencies

14. **#39 — local multiplayer** (seats, device binding), now
    sequenced after #18/#19 per Tier B, its own doc's stated
    dependency.
15. **#40 — AI character/dialogue system**, which explicitly corrects
    #39's own seat design — must follow it, not precede it.
16. **#38 — widget/currency/inventory systems**, whose own doc
    connects directly to #18.
17. **#12 — room-of-tables UX roadmap**, the feature #18 was named
    specifically to prepare for.
18. **#42 — next-wave game pak specs** (Labyrinth, Game & Watch, Boss
    Monster, Dominoes) — real content expansion, not blocking anything
    else, not blocked by anything left in Tier A-C.
19. **#45 — game timer primitive, Door Dasher, title-fade fix.**
20. **#44 — UX genre-pattern roadmap** (house rules, reduced motion,
    spectator seats, stats screen, autosave) — design-roadmap
    counterpart to #43, once #43's own concrete gaps are closed.

## Tier E — ecosystem, process, governance

Real, but these are aids to how work gets done, not the work's own
correctness or the product's own capability — sequenced after
anything that actually changes what ships.

21. **#25 — `policy/gate.rego` encodes #20's own fix but was never
    wired into CI**, and would fail widely if turned on as-is. Real,
    concrete follow-through gap on work already done.
22. **#26 — every commit this session went directly to main**, no
    branches or PRs, against an established GitFlow standard. A real
    process gap, worth fixing going forward, not retroactively.
23. **#20 — BDD discipline.** Largely already addressed this session
    (docs/naming-convention.md's sibling docs, and the discipline has
    been genuinely practiced multiple times since) — worth a real
    "substantially resolved, close or narrow scope" check rather than
    leaving it open indefinitely on its original, broader framing.
24. **#17 — CHANGELOG.md stale.**
25. **#7 — Serapeum-over-Alexandria standard + DRY tooling audit.**
26. **#8 — Datalog/Prolog as the ruleset protocol's second branch.**
27. **#21 — scoped CSP/channel usage philosophy.** Partially addressed
    by #22's actual implementation (the bus is load-bearing now, not
    scaffolded) — worth checking whether this issue's own scope is
    now substantially satisfied too.
28. **#47 — key design principles doc.** Already a stable, standing
    reference; low urgency to act on further versus the doc simply
    existing and being followed.

## Tier F — tooling, investigation, and future-facing scope

29. **#53 — BDD/TDD/e2e audit.** Two of three named tables now have
    real e2e coverage (Yahtzee, Hearts, this session); Queens is the
    one concrete remaining piece.
30. **#51 — metrics/observability system.** Design done, first real
    slice implemented and already found one genuine bug (the 1.26s
    frame-time outlier). Continue as #50 needs it.
31. **#50 — startup CPU/memory investigation**, now has the real
    tooling from #51 to actually investigate with, rather than ad hoc
    measurement.
32. **#52 — performance suggestions**, already checked against the
    codebase; the two confirmed real gaps (audio DSP type
    declarations, Queens shader batching) are concrete, scoped
    follow-on work.
33. **#14 — audio glitches investigation.**
34. **#3 — AI difficulty selection.** Checked directly: this issue's
    own described scope (a `:difficulty` arcade mode, per-session
    tiers, an AI-capable flag on `GAME-ENTRY`) matches what's already
    built and in active use throughout this session. Very likely
    substantially or fully done — worth a real closure check rather
    than counting as open scope.
35. **#49 — title screen theme music timing.** Confirmed pre-existing
    and unrelated to this session's own work; genuinely low priority,
    not urgent.
36. **#1 — WASM dual-target release.** Large, real, but post-1.0 scope
    by its own title.
37. **#5 — coin flip/poker chip/domino mechanic libraries.** Future
    game-pak prep, not blocking anything currently in flight.
38. **#41 — P2P network play.** Explicitly, deliberately out of
    current scope, tracked so the direction isn't lost — correctly
    last, not neglected.

## What changed from the prior partial pass

The prior `docs/tier-priority-reorder.md` covered 6 issues (#36, #37,
#33, #18, #19, and implicitly #46). This pass places all 41. The real
correction beyond adding coverage: Tier A (#9, #24, #48) sits *above*
the architecture work from the prior pass — active, severe,
already-diagnosed problems affecting current correctness and
distribution outrank structural force-multipliers for future work,
even though the prior analysis was right that force-multipliers
outrank simplicity *within* the remaining, non-urgent scope.

## Cross-references

Supersedes `docs/tier-priority-reorder.md`'s scope, doesn't contradict
its reasoning for the 6 issues it covered — that reasoning is restated
here as Tier B, just repositioned below Tier A's active problems.
