# Next-wave game paks — Labyrinth, Game & Watch, Boss Monster, Dominoes

Status: design proposal, not implemented. Four full game specs per
direct instruction, grounded in research (dominoes rules verified via
search; Labyrinth verified earlier this session; `GET-FRAME-TIME`
confirmed actually exported by `cl-raylib` before designing Game &
Watch's protocol around it) rather than invented from memory. Each
section states plainly what reuses already-designed infrastructure
(#36 layout, #37 style/VFX, #38 currency/inventory/widgets/collectibles/
achievements, #39 seats, #40 AI characters) versus what's a genuinely
new subsystem this table exposes.

---

## 1. Multiplayer Dominoes

The one that "got skipped" -- #5 only ever covered visual effects
(coin-flip/poker-chip/domino animation shaders), never the actual game.
This is the real spec.

### Rules, verified

Standard double-six set, 28 tiles (every unique 0-6 pair including the
7 doubles). Draw variant as the default (richer than Block -- a player
who can't match draws from the boneyard until they can play or it's
empty, rather than just passing) -- 2 players draw 7 tiles each, 3-4
players draw 5 each (matching every source checked). First to play
every tile in hand wins the round; if play blocks (boneyard empty, no
one can move), lowest pip count in hand wins. Match to a target score
across rounds (100 is the commonly cited default). All Fives (bonus
scoring when open chain ends sum to a multiple of 5) is a real,
well-documented variant worth supporting as a table option later, not
required for a first version.

### Board shape -- genuinely new, not a fit for any existing primitive

A domino chain has two open ends and grows in either direction as tiles
are played -- not a fixed grid (Queens), not a hand-plus-trick (Hearts),
not a row of fixed slots (Boss Monster, below). Needs its own layout
primitive: a growable, bidirectional sequence with two live "open end"
anchor points tiles can be appended to. Worth flagging for #36 as a
fourth genuinely distinct board shape, alongside the row-shape Boss
Monster needs.

### Reuses existing infrastructure directly

- **Hand widget**: a domino hand is structurally the same interaction
  as a card hand -- select from a set of rectangular tiles you hold.
  `#38`'s planned `CARD-HAND-WIDGET` should generalize to tiles rather
  than this table inventing a second, parallel widget.
- **Seats/multiplayer (#39)**: dominoes is inherently a social,
  multiplayer game (2-4 players) -- the natural first table designed
  multiplayer-first from the start, rather than a single-player-plus-AI
  table retrofitted for local multiplayer later the way Hearts would be.
- **AI characters (#40)**: AI seats need domino-specific decision logic
  (which tile to play, when to hold a double for blocking), but the
  *character identity/dialogue* is the same shared roster already used
  elsewhere -- Larry taunting over dominoes uses the same
  `DIALOGUE-VOICE` structure, not a domino-specific character set.
- **Scoring**: plain `GAME-SCORE`/`GAME-OUTCOME`, matching Hearts/
  Yahtzee -- no currency or inventory needed for this table.

### What's new

Just the chain-layout primitive above. Everything else composes
existing, already-designed systems -- this is close to the "small,
real first retrofit" #36/#37/#39 have all been waiting for, arguably
the cheapest of the four to actually build.

---

## 2. Game & Watch series -- where the real protocol gap actually lives

Genuinely real-time, unlike the other three (all turn-based). This is
the concrete scope for the gap #38/#40 already flagged but didn't
design in detail.

### Candidate titles, a representative starting set, not the whole series

Not attempting to spec "the whole series" -- three concrete, well-known
titles as the initial scope:
- **Fire!**: catch people jumping from a burning building in a blanket
  moved left/right along the ground.
- **Manhole**: reposition manhole covers so a walking pedestrian crosses
  safely across gaps.
- **Octopus**: a diver retrieving treasure while avoiding tentacles that
  sweep the screen.

All three share the same shape: continuous position control (not
discrete grid movement), collision detection against moving hazards,
and a lives/timer-based session rather than a turn-based one.

### The protocol extension, designed concretely, verified against what's actually available

`GAME-UPDATE` (`game-protocol.lisp`) has no delta-time parameter today
-- confirmed, not assumed, in #38/#40's earlier flagging. `raylib`
genuinely exports `GET-FRAME-TIME` (checked directly in
`cl-raylib/src/package.lisp` before designing around it). The extension:

```lisp
(defgeneric game-update-realtime (game dt))  ; DT = (raylib:get-frame-time),
                                              ; called from MAIN's loop
                                              ; instead of GAME-UPDATE for
                                              ; tables that declare
                                              ; themselves real-time
```

A table opts into this (a slot on its `GAME-ENTRY` registration,
`:realtime-p`) rather than every table's dispatch changing --
turn-based tables keep calling plain `GAME-UPDATE`, unaffected. Position
integration inside a real-time table's own `GAME-UPDATE-REALTIME`
method: `(incf (blanket-x game) (* velocity dt))`, the standard
consistent-timestep pattern this genre needs and the turn-based tables
never did.

### Reuses existing infrastructure

- **VFX (#37)**: collision effects, the catch/miss feedback, camera
  shake on a miss -- exactly what #37's event-driven, arena-backed
  effect pipeline is for. This table is arguably the *best* proof case
  for #37's design, more than any turn-based table would be, since
  visual feedback timing is the entire genre.
- **Seats (#39)**: not simultaneous multiplayer (these are single-
  screen, one-player-at-a-time titles historically), but local
  alternating-turn high-score attempts fit the hotseat framing loosely
  -- seat 0 plays a round, seat 1 plays a round, compare scores. Not
  designing this interaction in detail here.
- **No currency, inventory, or AI opponents** -- there's no
  adversary to characterize, no resource to spend. Genuinely the
  simplest of the four in terms of subsystem breadth, despite being the
  architecturally hardest due to the protocol extension.

### What's new

The real-time protocol extension itself (above) -- the one piece of
core-engine change any of these four tables actually requires, since
everything else in this doc composes already-designed systems without
touching `game-protocol.lisp`.

---

## 3. Boss Monster

Real, shipped tabletop game -- designing against its actual shape,
hedging where exact numeric details aren't certain rather than
asserting false precision.

### Rules, as understood -- flagged where uncertain

Each player builds a dungeon: a row of room card slots. Players draw
and play room cards into their row, and spend build points to construct
rooms (each room typically has an elemental/class affinity -- fire,
mind, etc. -- that deals bonus damage to matching hero types). A shared
hero deck is drawn from each round; heroes advance through a player's
dungeon row room by room, taking damage as they pass through rooms
matching their weakness. A hero defeated in your dungeon yields souls
(the currency); a hero who survives all the way through deals damage to
your own "hero" (the hidden identity in Boss Monster's own established
lore) instead. First to a target soul count wins -- not asserting the
exact number here, since editions/expansions vary and this doesn't
change the architecture.

### Board shape -- the row primitive, scoped for real now

A player's dungeon is a bounded row of N slots (not growable in both
directions the way a domino chain is -- a fixed-length sequence filled
left-to-right or by explicit slot choice). Distinct from dominoes'
bidirectional chain and from Queens'/Labyrinth's 2D grid -- the third
genuinely new board shape named across this doc, worth scoping as a
`ROW-WIDGET`/row-layout primitive for #36 now that a real table needs
it, rather than staying a placeholder.

### Reuses existing infrastructure directly

- **Currency (#38)**: souls are the real, first consumer #38's
  `CURRENCY-POOL` was designed against from the start -- this table is
  why that section exists.
- **Hand widget**: room-card and hero-response hand management is the
  same `CARD-HAND-WIDGET` shape as Hearts/dominoes.
- **AI characters (#40)**: an AI opponent building a rival dungeon
  needs Boss-Monster-specific room-placement/luring decision logic, but
  again, shared character identity/voice with the existing roster.
- **Collectibles/achievements (#38)**: a natural fit for later --
  "defeat 20 heroes across all sessions" as an achievement, a
  collectible that temporarily boosts one room type's damage -- not
  required for a first version, noted as a natural extension once the
  base table exists.

### What's new

The row-layout primitive (above). Everything else is currency,
widgets, and AI characters already designed and waiting for a real
consumer -- this table and dominoes are the two cheapest of the four to
build for exactly that reason.

---

## 4. Mattel's D&D Computer Labyrinth Game -- adapted with real visual styling

Direct correction incorporated from earlier in this session: not a
blank grid and sound effects, a real visual adaptation that keeps the
audio-cue system as a genuine parallel channel rather than the only one
(matching the original's own design intent, translated rather than
copied wholesale).

### Rules, verified earlier this session

8x8 grid. A player moves up to 8 squares per turn; the dragon moves 1.
50 walls, one dragon, and treasure are placed randomly and are
*invisible* until a player moves into or adjacent to them -- the
core fog-of-war mechanic. The original hardware had no screen at all;
twelve distinct audio cues told the player what they'd encountered
(wall, door, treasure, the dragon, etc.). Combat is minimal -- three
hits from the dragon and a player is sent back to their own secret
room. The goal is retrieving treasure to your own secret room.

### Visual adaptation, the actual scope of the correction

The grid renders using the already-built `CENTERED-GRID-POSITIONS`
(#36, the same primitive Queens uses) -- but cells are **not** uniformly
blank. A discovered cell renders its actual content (wall segment, door,
treasure glint, the dragon's position once encountered) using this
engine's own vector/glyph visual language (matching the established
"don't copy source material's literal art, build this engine's own
equivalent" discipline from #40's character-glyph decision). An
*undiscovered* cell renders as genuinely blank/fogged -- the visual
fog-of-war state is the actual gameplay information a screen adds over
the 1980 original, while the twelve-cue audio vocabulary plays
alongside every discovery, not replaced by the visual, layered with it.

### Two genuinely new subsystems this table needs -- named, not designed in full here

- **Fog-of-war / progressive discovery**: per-profile (or per-session,
  a real open question -- see below), a `DISCOVERED-CELLS` set on the
  board state, checked before rendering a cell's true content versus
  its fogged placeholder. No existing table has any hidden-information
  mechanic to generalize from -- this is genuinely new, not a
  retrofit of something that exists.
- **Simple combat/HP**: a player has a hit count (3 hits = returned to
  secret room, matching the original); the dragon's own movement/attack
  resolution is turn-based and simple, not a combat *system* in the RPG
  sense -- worth keeping deliberately minimal, matching the original's
  own restraint, not an invitation to build a full combat engine for a
  table that doesn't need one.

### Reuses existing infrastructure directly

- **Grid layout (#36)**: `CENTERED-GRID-POSITIONS`, unchanged from
  Queens.
- **Inventory (#38)**: treasure/keys carried toward the secret room are
  the real, first consumer #38's inventory design was built against.
- **Audio subsystem**: the twelve-cue vocabulary is new *content*
  (twelve distinct short cues), not new audio *infrastructure --
  `pattern-sound`/`play-tone` (already verified sound this session)
  are sufficient to produce them.
- **Seats (#39)**: originally two-player head-to-head -- a genuine,
  direct multiplayer consumer alongside dominoes.

### Open question, not resolved here

Whether discovered-cell state resets per session (a fresh maze every
game, matching the original's own random-placement-per-game design) or
persists somehow across a profile's sessions -- leaning strongly toward
per-session (matching the original exactly, and avoiding a strange
"the maze is already partially known" experience), but flagging rather
than silently deciding.

---

## Cross-references

All four extend #36 (three new layout primitives named: domino chain,
Boss Monster's row, Labyrinth's grid reuse), #37 (Game & Watch is the
strongest VFX-pipeline proof case named yet), #38 (currency's real
consumer is Boss Monster, inventory's is Labyrinth), #39 (dominoes and
Labyrinth are both genuinely multiplayer-first), #40 (every table with
AI opponents shares the same character roster, not per-table casts).
Game & Watch's real-time protocol extension is the one piece of
`game-protocol.lisp` itself any of these four actually requires.

Not implemented. Dominoes and Boss Monster are the cheapest to build
first (composing almost entirely existing, already-designed
infrastructure); Labyrinth needs two genuinely new subsystems (fog-of-
war, simple combat); Game & Watch needs the one real core-protocol
change. Scoping which becomes the actual first PR is the next step once
this direction is confirmed.
