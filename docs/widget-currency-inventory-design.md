# Widget/dialog, easter-egg, currency, and inventory systems — grounded in three named, real consumers

Status: design proposal, not implemented. Architecture document per
direct instruction. Every system below is scoped against three specific
planned games, not designed as generic abstractions in search of a use
case — matching this project's established discipline (cards/dice
libraries, #5's coin-flip/poker-chip, #8's Datalog branch) of building
against real, named need.

## The three real consumers, researched not assumed

**Dungeons & Dragons Computer Labyrinth Game (Mattel, 1980)** — verified
via direct research, not recalled from fuzzy memory. 8x8 grid board.
Turn-based: a player moves up to 8 squares/turn, the dragon moves 1.
The computer randomly places 50 invisible walls, a dragon, and treasure
at game start -- nothing is visible until discovered by moving into it.
The original hardware had no screen and no lights at all -- twelve
distinct audio cues told the player what they'd walked into (wall,
door, treasure, the dragon, etc.), audio as the *primary* information
channel, not decoration. Combat is minimal (three hits from the dragon
and a warrior is out, returned to their secret room). The goal is
retrieving treasure to a player's own secret room.

**Boss Monster** (real, shipped tabletop game) -- turn-based deck-
builder. Each player's board is a *row* of room cards (a dungeon),
distinct in shape from both Queens' grid and Hearts' hand-plus-trick.
Players lure hero cards through their dungeon row, dealing damage as
heroes pass through rooms, collecting "souls" (the game's currency)
from defeated heroes, spending souls/treasure to build and upgrade
rooms.

**Game & Watch Gallery** -- genuinely real-time, reflex-based
single-screen games (catching falling objects, avoiding obstacles,
timed placement). Unlike the other two, this is not turn-based at all.

## Where the real architectural gaps are, and where they aren't

Labyrinth and Boss Monster are both turn-based -- `GAME-UPDATE`/
`GAME-RENDER` (`game-protocol.lisp`) fits them as-is, the same protocol
every current table already uses. The genuine new requirements are data
and mechanics (fog-of-war, combat, currency, a row-shaped board), not a
different game-loop shape.

**Game & Watch Gallery is where an actual protocol gap lives.**
`GAME-UPDATE` has no delta-time parameter today -- every timing-
sensitive thing in this engine (`AI-TIMER`, `TWEEN`) reads
`raylib:get-time()` directly and computes its own elapsed time.
Workable for turn-based UI pacing (an AI "thinking" delay doesn't need
frame-accurate timing); wrong foundation for continuous position/
velocity integration a reflex game needs (`position += velocity * dt`,
computed consistently every frame). This needs a real protocol
extension -- a `GAME-UPDATE` variant (or a new generic,
`GAME-UPDATE-REALTIME`, dispatched only for tables that need it) that
receives an actual frame-delta, not each table re-deriving its own
timing from raw `get-time()` calls. Not designing the full real-time
protocol here -- flagging it as the genuine gap Game & Watch exposes,
worth its own design pass when that table is actually scoped, since it
touches the core protocol every other table also depends on.

## 1. Global easter-egg / unlock system

Connects directly to #12, which already names "easter eggs/unlockables"
as deferred UX scope -- this is that system, now with a concrete reason
to exist: it's the actual unlock gate for these three tables, not a
decorative extra.

**Two mechanisms, one registry:**
- **Achievement-style unlocks**: completing a condition in one table
  (e.g., winning Hearts by shooting the moon, solving all 25 Queens
  levels) sets a flag. `#12`'s room-of-tables reads these flags to
  decide whether Labyrinth/Boss Monster/Game & Watch are shown, hidden,
  or shown-but-locked.
- **Secret input sequences** (Konami-code style) -- detected at the
  arcade-shell level (`main.lisp`'s top-level input handling, not
  per-game), since a "global" easter egg needs to be checked regardless
  of which screen is active.

### Real gap this doc had, corrected: unlocks must be per-player-profile, not machine-global

An earlier draft of this section said unlocks are "profile-level" as a
throwaway phrase without actually designing what a profile is -- a real
gap once #39's local multiplayer exists. Up to four human players can
share one machine (#39); "who unlocked what" and "whose progress is
this" is a real, previously-unresolved question, not a detail. A single
machine-wide unlock flag set (what this doc originally implied) is
wrong the moment two different people are actually playing on the same
install.

```lisp
(defstruct player-profile
  (id nil :type keyword)              ; stable, unique per profile
  (display-name "" :type string)
  (unlocked-tables nil :type list)
  (unlocked-characters nil :type list) ; if #40's characters become unlockable
  (stats (make-hash-table)))          ; achievement/milestone tracking --
                                       ; the actual condition-evaluation
                                       ; substrate for UNLOCK-CONDITION-MET-P
```

**Profiles are optional and lightweight, not mandatory account
creation** -- matching #39's own "pick up and play, DOS-hotseat" framing
rather than a heavyweight login flow that would fight it. At join-time
(the same screen #39 already designs for seat-claiming), a human seat
either selects an existing profile, creates a new lightweight one (a
name, nothing more), or plays as an unprofiled guest (no persistent
progression tracked for that session, matching today's behavior
exactly). This means **#39's `SEAT` struct needs one more field**:

```lisp
(defstruct seat
  (controller :ai :type (member :human :ai))
  (device nil)
  (profile nil)      ; a PLAYER-PROFILE, or NIL for a guest seat --
                      ; only meaningful when CONTROLLER is :HUMAN
  (ai-character nil))
```

**Unlock conditions evaluate per-profile, against that profile's own
stats** -- not "has anyone ever shot the moon on this machine," but
"has *this* profile." In a shared session with multiple human seats,
an achievement belongs to whichever seat's profile actually earned it
(the player who shot the moon), not everyone at the table -- matching
how per-player achievements normally work in any local multiplayer game
with individual profiles, not a shared machine-wide unlock pool.

**Persistence is a real, separate design question, not reuse of save
slots.** The existing save system (`save.lisp`, `*SAVE-SLOT-COUNT*` =
10) is per-session, per-table game state -- explicitly not what unlock
flags are, and explicitly not currently profile-scoped either (worth
noting as an open question below, not resolving it here). Unlock/
profile data should live in its own file per profile (e.g.
`~/.parencade-saves/profiles/<id>.sexp`, sibling to but structurally
distinct from the numbered save slots) -- conflating unlocks with save
slots would mean deleting a save slot could plausibly re-lock a table,
which is wrong regardless of the profile question.

```lisp
(defgeneric unlock-condition-met-p (condition-id profile))  ; per-table
                                                              ; methods,
                                                              ; now profile-aware
(defun check-unlocks (seat))  ; called on table-return, reads SEAT-PROFILE,
                               ; not every frame, not machine-global
```

## 1a. Meta-progression and the collectible "effect engine" -- modeled on dwightaspencer.com's own cross-property easter-egg pattern

Direct reference, verified rather than assumed: `dwightaspencer.com`'s
own `00-hellowrld` post describes exactly this shape already in
practice -- "thanks to Soft Serve one can find security research
whitepapers, talks and presentations, and a few easter eggs on my
self-hosted git repos" via SSH into a separate server (`hack.dapla.net`).
The pattern is a *meta* discovery system spanning multiple separate
surfaces, not one isolated page or one isolated game. Translated to
this engine: collectibles discoverable across *any* table, not confined
to the table where they're found, matching that cross-property spirit.
(Noted honestly: this is the shape confirmed by that reference, not a
claim of having explored `hack.dapla.net` itself -- designing from what
was verified plus what was described directly.)

### Rank/score progression drives discovery, via bus events like everything else

Extends `PLAYER-PROFILE` (already added above) with rank/score tracking:

```lisp
(defstruct player-profile
  ...                          ; id, display-name, unlocked-tables, stats
  (rank 0 :type fixnum)
  (score-total 0 :type fixnum))
```

Rank-up is a semantic event, same bus pattern as VFX (#37) and dialogue
(#40) -- not a special case:
```lisp
(bus-push *engine-bus* :meta (list :rank-up profile new-rank))
```

### Collectibles are discovered via a joint query -- table facts *and* profile facts -- the real case #8 was missing

A collectible's discoverability isn't just "profile rank >= N" (a
simple threshold) or just "this table" (a simple location check) -- per
the brief, it's *both together*: which table, what's currently true
about the session, and what's true about the profile finding it. That's
a genuine multi-source fact query, not a single flag check:

```lisp
(defstruct collectible
  (id nil :type keyword)
  (display-name "" :type string)
  (discovery-condition nil)   ; a fact/rule query -- #8's territory
  (effect nil))               ; what this collectible asserts when activated, see below
```

### Activation asserts a session-scoped fact; effects chain -- this is where #8 earns its keep more clearly than #40's case did

The brief's own example: a collectible found once, activated
temporarily for one table, that doubles points on even-numbered Hearts
cards. Activating a collectible asserts a fact scoped to the current
session, not a permanent profile change:

```lisp
(activate-collectible profile collectible-id)
;; e.g. asserts (:active-modifier :double-even-hearts) for this session only
```

**Multiple active collectibles must compose, not just override each
other one at a time** -- "double even hearts" and a second, different
collectible ("triple all spades") active simultaneously both need to
apply, correctly, to their respective cards. That's real rule
composition across multiple simultaneously-true facts, which is exactly
what a fact-plus-rule query engine handles cleanly and an ad hoc
`COND`/`IF` chain in each game's scoring code does not -- the "chain
together as an effect engine" the brief names directly is the concrete
description of a Datalog-style query resolving multiple applicable
rules at once, not a queue of single-effect overrides applied in
sequence. **This is a stronger, more concrete case for #8 than #40's
gamerule-facts example** -- #40 needed conditional adjustment of one
value; this needs genuine composition of an open-ended number of
simultaneously-active modifiers, which is a correctness problem a
simple cascade (#37's last-wins model) cannot solve, not just a
convenience #8 would add.

### How a table actually queries this

When Hearts computes round scoring, it queries active facts for
applicable modifiers rather than hardcoding "if this specific
collectible is active" checks in `SCORE-ROUND` itself:

```lisp
;; illustrative, not committing to #8's eventual query syntax
(effective-score card base-score (active-facts-for profile :hearts))
```

Keeps game logic (`hearts/game.lisp`) ignorant of which specific
collectibles exist -- it queries "what modifiers apply to this card
right now," the same discipline that already keeps `SCORE-ROUND` itself
independent of a second, separately-maintained rule check (see its own
existing docstring).



Connects directly to #18 (arcade-state's one-cursor-field-per-screen
pattern, already flagged as not scaling) and #36 (layout DSL, which
this composes with rather than duplicates). Every current "dialog" --
the pause popup, the save/load browser, the difficulty screen -- is
hand-built with its own cursor-index struct field and its own
input-handling `COND`/`CASE` block. That already doesn't scale past
four screens (#18's finding); Boss Monster's "select a card from your
hand to place in your dungeon row" and Labyrinth's inventory display
are both *richer* interactions than any current screen's simple list-
menu, not simpler ones.

**A real widget protocol**, composing #36's layout primitives and
#37's style pipeline rather than reinventing positioning or visuals:

```lisp
(defgeneric widget-focus-next (widget))
(defgeneric widget-focus-previous (widget))
(defgeneric widget-activate (widget))     ; Enter on the focused item
(defgeneric widget-render (widget resolved-style))
```

A `LIST-WIDGET` (generalizing every current menu/browser into one
implementation instead of four hand-rolled ones), a `GRID-WIDGET`
(Queens already needs this shape; Labyrinth's inventory display and
board would too), and a `CARD-HAND-WIDGET` (Hearts' hand already has
this shape informally; Boss Monster's dungeon-building needs it as a
real, selectable widget, not just a row of drawn cards).

**This is the structural fix for #18**, not a workaround -- once
screens are built from composed widgets instead of hand-rolled cursor
fields, `ARCADE-STATE` doesn't need a new index field per screen; a
widget owns its own focus state.

## 3. Modular currency system

Boss Monster's souls are the real, first consumer -- no current table
has any currency concept (Hearts has penalty points, Queens/Yahtzee
have scores, neither is spendable). Deliberately simple, matching the
"don't over-engineer" discipline already established for this codebase
-- a named, per-player integer resource with earn/spend hooks, not a
full economic simulation:

```lisp
(defstruct currency-pool
  (balances (make-hash-table) :type hash-table))  ; player-index -> amount

(defun earn (pool player amount) ...)
(defun spend (pool player amount) ...)  ; returns NIL if insufficient, doesn't error
```

Genuinely reusable beyond Boss Monster once a second consumer exists
(a hypothetical shop/upgrade mechanic in a future table) -- not
building anything beyond this shape until one does.

**Distinct from collectibles (section 1a), not overlapping with them
-- reinforced directly, no shared data structure and no shared
resolution path between the two.** Currency is per-table, in-session,
spendable within that table's own rules (Boss Monster's souls only
mean something inside a Boss Monster game) -- `CURRENCY-POOL` lives on
the table's own game state, not on `PLAYER-PROFILE`. Collectibles are
cross-table, profile-owned, and persist between sessions -- a meta-
progression reward, stored on `PLAYER-PROFILE`, resolved via #8's
fact-query mechanism, not spent through a table's own rules. They serve
different functions and don't share a code path: `EARN`/`SPEND`
(currency) never touch `ACTIVATE-COLLECTIBLE`'s fact-assertion, and
vice versa. A future table can use both without either concept ever
needing to absorb or delegate to the other.

## 4. Modular inventory system

Labyrinth's treasure/keys are the real, first consumer. A per-player
collection of named items, list-backed (matching how Hearts already
represents a hand as a plain list of cards, not a new data shape for
this codebase):

```lisp
(defstruct inventory
  (items nil :type list))  ; plain list of item plists, matching card-as-cons convention

(defun inventory-add (inv item) ...)
(defun inventory-remove (inv item) ...)
(defun inventory-has-p (inv item-name) ...)
```

Deliberately not slot-limited or weight-based in v1 -- Labyrinth's own
mechanic (carry the treasure back to your secret room) doesn't need
capacity limits; add that constraint if/when a second consumer actually
needs it, not speculatively.

## 5. Achievement system -- global, distinct from both unlocks and collectibles

A third, separate concept from the two already designed above --
worth being precise about the boundaries rather than letting these
blur together:

- **Unlocks** (section 1) are access-control: a condition met *gates*
  something (a table, a character).
- **Collectibles** (section 1a) are usable meta-progression rewards
  with gameplay effects when activated.
- **Achievements** are records of accomplishment -- recognition, not
  access control and not a usable item. Earning one doesn't inherently
  unlock or activate anything; it's tracked and displayed. (An
  achievement *can* be the trigger condition an unlock or a collectible-
  discovery query checks against -- see below -- but the achievement
  itself carries no gameplay effect or access change on its own.)

### Global, and integrates with table games -- one system, per-table vocabulary, same pattern as #40's dialogue events

Committing explicitly here, not left hedged the way an earlier draft
worded it ("a predicate/fact-query" implied either a plain Lisp
predicate or a Datalog query, as if either would do): **achievement
conditions are Datalog queries, specifically, not ad hoc predicate
functions.** This is deliberate, not just consistent with #8 for its
own sake -- achievements are exactly the case that most needs it.
Simple unlocks (section 1) stay plain per-table `DEFGENERIC` dispatch,
reasonably, since most don't need cross-fact composition. Achievements
routinely will: "won three different tables in one session," "beat
`:larry` at both Hearts and Yahtzee," "earned this while a specific
collectible was active" are genuine multi-fact conjunctions over
profile stats, table history, and possibly other already-earned
achievements -- exactly the shape a hand-written predicate function
gets unwieldy for fast, and a Datalog query handles as its normal case.

```lisp
(defstruct achievement
  (id nil :type keyword)                ; e.g. :hearts-shot-the-moon-5x
  (display-name "" :type string)
  (table nil :type (or null keyword))   ; NIL = cross-table/meta-game
                                         ; achievement; a keyword = earned
                                         ; through a specific table, but
                                         ; tracked by the same global system
  (condition nil))                      ; a DATALOG QUERY over the profile's
                                         ; STATS (and, per the multi-fact
                                         ; examples above, potentially table
                                         ; facts and other earned
                                         ; achievements too) -- #8's
                                         ; mechanism specifically, not a
                                         ; hand-written predicate
```

`PLAYER-PROFILE` already has a `STATS` hash-table (raw counters --
"times shot the moon: 5") from the unlock-condition design above.
Achievements are the *derived, named* layer over that raw data, not a
duplicate of it:

```lisp
(defstruct player-profile
  ...
  (stats (make-hash-table))       ; raw counters, unchanged from above
  (earned-achievements nil :type list))  ; NEW -- named, discrete
                                          ; milestones derived from STATS,
                                          ; not another counter
```


**"Integrates with the table games" means one global processor, a
per-table event vocabulary** -- the same shape #40 already establishes
for dialogue (Hearts defines `:trick-won`/`:shot-the-moon`, Yahtzee
defines `:yahtzee-rolled`, the consumer is generic across every table).
An achievement processor listens on both table-specific game events
*and* `:meta` events (rank-up, collectible discovery) -- "global" means
it's not confined to one topic or one table's vocabulary, not that
there's a second, separate mechanism for meta-game achievements versus
table achievements.

### Relationship to unlocks and collectibles -- feeds them, doesn't duplicate them

An achievement being earned can be *one of* an unlock's or a
collectible-discovery's fact-query inputs (e.g., "this collectible is
discoverable if the profile has earned `:hearts-shot-the-moon-5x`") --
composing with #8's fact-query mechanism the same way table facts and
profile rank already do, not a fourth, separate resolution path.



- The full real-time protocol extension Game & Watch needs -- flagged
  as a real gap, not designed in detail, since it deserves its own pass
  scoped against that table specifically, and touches the core protocol
  every other table depends on.
- Fog-of-war/hidden-state and combat/HP resolution for Labyrinth --
  real, named gaps this table exposes, worth their own design once
  Labyrinth is actually being scoped, not invented here speculatively
  ahead of that.
- Boss Monster's row-shaped board layout as a fourth primitive in #36 --
  worth adding once Boss Monster is scoped for real; not designing a
  primitive against a game that isn't built yet.
- **Whether the existing save system (#9) should become profile-scoped
  too**, now that profiles exist as a real concept -- a real, related
  question (should Dwight's save slots be distinct from a guest's, or
  from another profile's) but not resolved here. #9 already has enough
  tracked scope (the deceptive-save bug, missing error handling); this
  is a genuine follow-on for that issue once profiles land, not a
  reason to reopen #9's design now.

## Cross-references

Extends #12 (unlock gate for the concrete tables this issue already
deferred), #18 (the widget system is the structural fix, not a
workaround), #36 (widgets compose layout, don't duplicate it), #37
(widgets compose the style pipeline for visuals). Revises #39's SEAT
struct a second time (first for AI-CHARACTER per #40, now for PROFILE)
-- both revisions are additive fields, not conflicting redesigns.
Gives #8 its strongest case yet (section 1a) -- genuine multi-fact
composition across simultaneously-active collectibles, a correctness
problem #37's simple cascade cannot solve, stronger than #40's single-
value gamerule-facts example. Notes a real, unresolved follow-on for
#9 (save-slot profile-scoping) without resolving it here. Section 5
(achievements) is deliberately kept separate from both unlocks and
collectibles -- three distinct concepts, one shared profile/bus/fact-
query substrate, not three separately-invented mechanisms.

Not implemented. This is the architecture and the reasoning grounding
it in three specific games; scoping which system gets built first, and
against which of the three tables, is the next step once this direction
is confirmed.
