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

**Persistence is a real, separate design question, not reuse of save
slots.** The existing save system (`save.lisp`, `*SAVE-SLOT-COUNT*` =
10) is per-session, per-table game state -- explicitly not what unlock
flags are. Unlocks are profile-level, persist across every session
regardless of save slot, and should live in their own file (e.g.
`~/.parencade-saves/unlocks.sexp`, sibling to but structurally distinct
from the numbered save slots) -- conflating the two would mean deleting
a save slot could plausibly re-lock a table, which is wrong.

```lisp
(defgeneric unlock-condition-met-p (condition-id))  ; per-table methods
(defun check-unlocks ())  ; called on table-return, not every frame
```

## 2. Core widget/dialog system

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

## What's explicitly out of scope here

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

## Cross-references

Extends #12 (unlock gate for the concrete tables this issue already
deferred), #18 (the widget system is the structural fix, not a
workaround), #36 (widgets compose layout, don't duplicate it), #37
(widgets compose the style pipeline for visuals).

Not implemented. This is the architecture and the reasoning grounding
it in three specific games; scoping which system gets built first, and
against which of the three tables, is the next step once this direction
is confirmed.
