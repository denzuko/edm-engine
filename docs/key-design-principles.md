# Key design principles — standing rules, not systems

Status: design proposal, not implemented. Four standing principles from
a final gut-check, two answered directly and two carried forward from
that check. These are engine-wide *rules* rather than *systems* (unlike
#36-#46, which each design a subsystem) -- the distinction matters:
nothing here needs a new struct or protocol on its own, each is a
constraint the systems already designed should be built to honor.

## 1. Progression philosophy -- open-ended like Minecraft's, with solid, felt rewards and a sense of direction

Direct answer, not architecture invented from scratch -- this confirms
and extends #38's already-designed unlock/achievement/collectible
system rather than replacing it.

**Starter set, small and deliberate.** New players get the currently-
shipped tables plus Dominoes (#42) plus a small set of additional
"classics" -- not the full roster immediately. #12's room-of-tables
already supports this shape (unlock flags gating which tables show,
are hidden, or are locked) -- this confirms that design's direction was
right, not a new requirement on it.

**Triggering progression is achievements/unlocks, explicitly not
currency.** Confirmed directly, matching what #38 already designed
independently: currency (`CURRENCY-POOL`) is a per-table mechanic a
table imports (Boss Monster's souls), not a meta-progression driver.
Achievements and unlocks are the actual triggers -- a rewarding notice
or screen effect on the moment itself, then new content (house rules,
additional AI characters/avatars) becomes available on a subsequent
playthrough, not mid-session. This confirms #38's discovery-as-earned
design direction and gives it a concrete cadence: reveal happens
between sessions, not interrupting the current one.

**The real-world analogy, mapped directly onto what's already
architected, not just a mood-board reference:**

| Game-store journey | This engine's architecture |
|---|---|
| Buy a game, play alone at home | The current tables, solo |
| Play with friends | #39's local multiplayer |
| Open-table events, tournaments | #41's deferred P2P layer (same shape, not built yet) |
| Buy addons for new features | #37's game-pack override system, #42's new game paks |

Worth stating plainly: this mapping being this clean is a good sign the
architecture actually serves the vision, not just technically sound in
isolation -- most of what would be needed for this journey already has
a home in an existing design.

**Sociability as a real VFX requirement, not a business aside.**
Discovery/unlock moments are explicitly meant to carry social/replay
value (Twitch/Instagram-shareable) -- this is a concrete constraint on
#37/#46's effect work for these specific moments: designed to be
genuinely screenshot/clip-worthy, not just functionally correct. Worth
flagging explicitly to whoever builds that specific effect rather than
leaving it as an unstated expectation.

**The engine's own identity, stated directly**: outside the game paks
and meta-game, the engine itself is meant to function as a rapid-
development platform for future titles, explicitly compared to Sierra
On-Line/Infocom's 1980s model (a reusable engine underneath many
shipped titles). This reframes this session's architecture investment
(DSLs, the game-pack override boundary, the widget system) as platform
capital for multiple future titles, not scope spent on one compilation
-- worth stating explicitly since it changes how the earlier
architecture-to-implementation ratio concern should be read.

## 2. Save/profile schema versioning -- against the real spec, correcting an earlier wrong guess

Correction, not a refinement of the earlier draft: `cispec.org` is a
real, specific thing -- `org.cispec`, a standard label namespace for
attesting "Change Items" (organization, hardware, software, evidence,
credentials, anything whose state affects service delivery, cost, or
risk), by Da Planet Security, part of the same dps-meta/cimatrix family
already encountered this session (#27's investigation). Fetched and
read directly rather than guessed at -- an earlier draft of this
section incorrectly suggested `clojure.spec` as the likely reference;
that was wrong, retracted here, not just superseded silently.

### The relevant part of the real spec, applied to save/profile data

Core terms REQUIRED for conformance on any tracked Change Item:
`organization`, `orgunit`, `owner`, `role`, `application`, `version`.
Extended terms include `specversion` (which version of the *spec
itself* a label set was authored against) and `checksum` (under the
`custody-chain` category -- provenance/integrity).

Not every core term maps cleanly onto a game save file, and forcing one
that doesn't would be worse than leaving it out -- `orgunit`/`role` are
enterprise-organizational concepts with no honest equivalent here. The
ones that do map directly, applied as `org.cispec.*`-style tags on
every save/profile file:

```lisp
;; illustrative -- a header block on save/profile data, not the whole schema
(:org.cispec.application "edm-engine"       ; or the specific table
 :org.cispec.version "0.4.2"                ; the game/engine version
                                             ; that wrote this file
 :org.cispec.specversion "1.0"              ; which cispec spec version
                                             ; these labels themselves
                                             ; conform to
 :org.cispec.owner :dwight                  ; maps directly onto #38's
                                             ; PLAYER-PROFILE id -- a
                                             ; save file's owner *is*
                                             ; the profile that created it,
                                             ; a genuinely direct fit,
                                             ; not a stretch
 :org.cispec.checksum "sha256:...")         ; direct answer to #9's
                                             ; already-flagged gap --
                                             ; no save-integrity checking
                                             ; exists anywhere today; this
                                             ; is the spec-aligned way to
                                             ; express it rather than a
                                             ; bespoke scheme
```

### `LOAD-PRIME` as a hash-lookup handler table plus a transducers pipeline, not a growing COND

With `org.cispec.version` (or a dedicated save-schema version distinct
from the game's own version, if those ever diverge) present on every
file, migration becomes exactly the shape asked for: a handler lookup,
not a hand-maintained conditional that grows linearly and messily as
versions accumulate.

```lisp
(defvar *migration-handlers* (make-hash-table :test #'equal))
;; keyed by (from-version . to-version), one single-step transform each
(setf (gethash '("0" . "1") *migration-handlers*) #'migrate-v0-to-v1)
(setf (gethash '("1" . "2") *migration-handlers*) #'migrate-v1-to-v2)

(defun load-prime (raw-data)
  (let* ((from (getf raw-data :org.cispec.version))
         (steps (migration-path from *current-version*)))  ; e.g. ("0" "1" "2")
    (transducers:transduce
     (transducers:map (lambda (step) (gethash step *migration-handlers*)))
     (transducers:fold (lambda (data handler) (funcall handler data)) raw-data)
     steps)))
```

This is a genuine third real consumer for `transducers` (#7's audit
found exactly two prior consumers, `arena.lisp` and
`wordle/guess.lisp`) -- composing the chain of single-step migrations
through a version gap is precisely the shape transducers exist for,
not a stretch application to hit a number.

Not urgent at pre-alpha with no real save files yet -- worth designing
now while it's cheap, per the same standing discipline #43 already
applies to other gaps found early.

## 3. Fixed-timestep simulation -- a real, unaddressed technical gap in #42/#45's real-time protocol design

Not answered directly, carried forward from the original gut-check.
`GAME-UPDATE-REALTIME` (#42/#45) was designed receiving a variable `DT`
(`raylib:get-frame-time()`) each frame. This is a well-known trap for
any simulation with position/velocity integration (Door Dasher, Game &
Watch): variable-timestep simulation is non-deterministic across
different machines and frame rates -- the same inputs produce different
outcomes depending on how fast the computer running it is, which shows
up as collision/timing bugs that are hard to reproduce and, if this
engine's future networked seats (#41) or replay/determinism ever
matter, breaks synchronization outright.

**Standard fix, not designed in detail here, just named as the
direction**: fixed-timestep simulation (accumulate `DT`, step the
actual game logic in fixed increments regardless of frame rate),
interpolating only the *rendering* between simulation steps using the
leftover fractional time. Worth deciding before Door Dasher or Game &
Watch are actually built, not discovered after as a bug -- exactly the
category of thing this whole audit/design phase exists to catch early
rather than expensively.

## 4. Determinism / seeded RNG as a standing rule, not a per-table fix

Not answered directly, carried forward. #43 found Wordle's target word
is genuinely unseeded (`(random (length *corpus*))`, no reproducibility).
That was filed as a Wordle-specific bug -- it's actually one instance of
a broader principle worth stating as a standing rule rather than
re-discovering table by table: **every source of randomness in this
engine should be seedable and reproducible on purpose.**

This matters more now than it did before this session's design work:
#39's local multiplayer and #41's eventual P2P both want reproducible
state for fairness and debugging (two players should be able to verify
they saw the same shuffle); #3's Screamer-driven AI decisions benefit
from reproducible seeds for testing (a bug report that includes a seed
should be reproducible, not "worked for me"); a future daily-challenge
mode (#43, #44) needs a date-derived seed specifically. Worth adopting
as a standing convention -- every `RANDOM` call in game-construction
code takes an explicit seed parameter, matching the pattern Queens'
board generation and the card shuffle already correctly use -- rather
than leaving it to be independently discovered as missing in each new
table.

## Cross-references

Section 1 confirms and extends #38, #12, #39, #41, #37, #42. Section 2
is grounded in the real `cispec.org`/`org.cispec` spec (Da Planet
Security, part of the dps-meta/cimatrix family from #27) -- its
`checksum` term directly answers #9's already-flagged save-integrity
gap, its `owner` term maps directly onto #38's `PLAYER-PROFILE`, and
`LOAD-PRIME`'s design gives `transducers` its third real consumer
(#7's audit found two prior). Section 3 extends #42/#45's real-time
protocol design. Section 4 generalizes #43's Wordle-specific finding
into a standing rule, connects to #39, #41, #3.

Not implemented -- standing principles for future work to be built
against, not new systems requiring their own implementation.
