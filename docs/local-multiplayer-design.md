# Local multiplayer — seats, device binding, join-flow, and network-readiness

Status: design proposal, not implemented. Load-bearing per direct
instruction -- this affects `game-protocol.lisp`, `arcade.lisp`, and
every multi-seat table's input handling, not an additive feature bolted
on alongside the others. Directly changes how #30 should actually be
fixed (see below) -- designing them together, not sequentially.

## What's being asked, precisely

Local ("DOS-style") multiplayer: multiple players around the same
keyboard/mouse/joystick(s)/screen, taking turns with input. On the
avatar/difficulty selection screen, up to four human players should be
able to join -- one is present by default, others claim a seat by
pressing a join action on their own device. Network play is explicitly
out of scope now, but the seat abstraction should not preclude a future
P2P (Raft/Kademlia/DHT, table-as-hosted-node, no hub-spoke server) layer
being added without restructuring what's built now.

## Grounded in what's actually there

`raylib`'s gamepad API is genuinely available in this binding --
verified directly (`cl-raylib/src/package.lisp` exports
`IS-GAMEPAD-BUTTON-PRESSED`, `IS-GAMEPAD-AVAILABLE`,
`GET-GAMEPAD-AXIS-MOVEMENT`, etc., the standard raylib set), not
assumed. `arcade.lisp`'s `ARCADE-COMPLETE-LAUNCH` currently tracks one
global `DIFFICULTY-INDEX` and `LET`-binds `*AI-DIFFICULTY*` for the
duration of a game's constructor call (the mechanism #30 found broken
-- it doesn't stay bound past construction). Every game's input
handling today calls `raylib:is-key-pressed`/`raylib:is-key-down`
directly, hardcoded to one fixed key vocabulary
(`:key-left`/`:key-right`/`:key-up`/`:key-down`/`:key-enter`/
`:key-escape`) -- confirmed zero mouse dependency anywhere (a real
positive from this session's audit), entirely keyboard today.

## 1. Device binding

```lisp
(defstruct device-binding
  (kind :keyboard :type (member :keyboard :gamepad))
  (gamepad-index nil :type (or null fixnum))
  (key-map nil :type list))   ; plist: :left/:right/:up/:down/:confirm/:back -> raylib key keyword
```

Two keyboard clusters that don't collide, matching the actual DOS-era
local-multiplayer convention this is modeled on:
- **Seat 0 (default)**: arrow keys + Enter + Escape -- the existing,
  unchanged scheme every current table already uses.
- **Seat 1 (keyboard join)**: WASD + Space + Tab (or similar --
  exact keys are a UX decision, not an architecture one).

**Honest constraint, not glossed over**: a standard keyboard genuinely
runs out of non-colliding key clusters past two simultaneous local
players. Seats 2 and 3 realistically need gamepads
(`DEVICE-BINDING` with `:kind :gamepad`, `:gamepad-index` 0-3 per
raylib's own indexing) -- a third/fourth keyboard cluster is possible
in principle but cramped and error-prone in practice. Worth stating
plainly in the design rather than implying four-player-on-one-keyboard
is equally viable as two.

## 2. Seats replace the single global `*AI-DIFFICULTY*`

This is the actual fix for #30, done as part of this design rather than
patched separately -- the bug exists because "AI difficulty" was
modeled as one ambient value when it needed to be a per-seat property
from the start:

```lisp
(defstruct seat
  (controller :ai :type (member :human :ai))
  (device nil)                        ; a DEVICE-BINDING, only when :human
  (ai-character nil))                 ; an AI-CHARACTER (see
                                       ; docs/ai-character-dialogue-design.md),
                                       ; only when :ai -- NOT a bare difficulty
                                       ; keyword. Correction: an earlier draft of
                                       ; this design used a bare :AI-DIFFICULTY
                                       ; tier here, which was itself the same
                                       ; genre of gap as #30's bug -- skill was
                                       ; never meant to be separable from a named
                                       ; character's identity and voice, per the
                                       ; Hoyle's Book of Games reference this
                                       ; project has carried since its earliest
                                       ; screenshots. See that doc for the
                                       ; character/dialogue system this seat
                                       ; field actually points at.
```

A table that supports N seats (Hearts/Yahtzee: 4; Queens/Wordle: 1, no
seat vector needed at all -- single-player tables don't grow this
complexity) gets a `(VECTOR SEAT ...)` created at launch. Seat 0
defaults to `(:CONTROLLER :HUMAN :DEVICE <default keyboard binding>)`;
seats 1..N-1 default to `(:CONTROLLER :AI :AI-CHARACTER <assigned
character>)`, exactly matching current behavior until someone joins.

**Turn-dispatch changes from a global check to a seat lookup.** Today,
e.g. Hearts: `(/= (hearts-game-turn game) 0)` -- hardcoded, seat 0 is
always assumed human. Becomes: `(eq :ai (seat-controller (aref seats
(hearts-game-turn game))))`. This is the real, durable fix -- #30's
avatar glyph bug was a symptom of the same underlying problem
(difficulty/controller-type not actually attached to the thing that
needs it at the time it's needed), not a one-line patch independent of
this.

## 3. Join-flow on the difficulty/avatar selection screen

Extends the existing screen rather than replacing it. Seat 0's avatar
card behaves as today (cycling difficulty is meaningless for seat 0
once it's human -- it always is). Seats 1..N-1 each show their current
state (AI + tier glyph, matching today, or a "press to join" prompt) --
pressing a join action on an *unclaimed* device converts that seat from
`:ai` to `:human`, binds the device that pressed it, and the seat's
displayed glyph/label switches from the pawn/knight/queen tier icon to
a player-number/color indicator. Pressing the same join action again
(same device) releases the seat back to AI -- a real toggle, not a
one-way commitment, so a player can back out before the table launches.

`ARCADE-COMPLETE-LAUNCH` passes the whole seat vector to the game's
constructor (not a single tier value) -- the game stores it, and every
per-seat decision (turn-dispatch, avatar glyph, AI pacing via
`AI-TIMER`) reads from it directly rather than an ambient special
variable.

## 4. Input reading goes through the seat, not raw raylib calls

The retrofit this requires is real and touches every multi-seat table's
`GAME-UPDATE`, not just new code -- worth being direct about the scope
rather than understating it:

```lisp
(defgeneric seat-pressed-p (seat action))  ; :LEFT/:RIGHT/:UP/:DOWN/:CONFIRM/:BACK
```

Dispatches on `(seat-device-kind seat)` to either the keyboard key-map
or the gamepad button/axis equivalent. Hearts' human-turn input
handling changes from `(raylib:is-key-pressed :key-enter)` to
`(seat-pressed-p (aref seats 0) :confirm)` -- mechanical at each call
site, but every call site needs touching. Not proposing to do this
across all four games in one pass; the natural first retrofit is
whichever table becomes the first real multi-human test case (Hearts,
given it already has four seats and the most natural "friends taking
turns" framing).

## 5. Network-readiness, without designing the network layer

P2P/Raft/Kademlia/DHT is explicitly out of scope -- not designing that
here. What matters now is not precluding it later, and the shape that
achieves that is already established elsewhere in this engine's
architecture: **a seat receiving player input should look the same
regardless of where that input originates.** `SEAT-PRESSED-P` polling a
local device today is one way to satisfy "this seat has an action
pending"; a future `:REMOTE` controller type receiving actions over the
network (via the same `CHANL` bus pattern #21/#22/#37 already
establish for producer/consumer decoupling -- a remote peer's action
arrives as a bus event, a per-seat consumer drains it, same shape as
the VFX event pipeline) would satisfy the same contract without
`GAME-UPDATE`'s own logic changing at all. The design commitment now is
just: **seat input is queried through an abstraction (`SEAT-PRESSED-P`
or equivalent), never raw device polling inlined into game logic** --
that's what makes a `:REMOTE` controller addable later without
retrofitting every table's `GAME-UPDATE` a second time. Nothing about
Raft/Kademlia/DHT needs deciding to honor that commitment today.

## Cross-references

Directly changes the fix shape for #30 (a per-seat property, not a
patch to the existing global). Extends #3 (AI difficulty is now
per-seat, reinforcing rather than conflicting with that issue's
remaining Screamer-lookahead scope). Connects to #21/#22/#37's bus
pattern for the network-readiness angle, without depending on that work
landing first -- local multiplayer doesn't need the bus, only the
*shape* of seat-input-as-abstraction needs to match it for a clean
future extension.

## Open questions, not resolved here

- Exact join-action keybinding for seat 1's keyboard cluster, and
  whether seats 2/3 should simply require a gamepad rather than attempt
  a third/fourth keyboard cluster -- a UX decision, not architecture.
- Whether `SEAT-PRESSED-P` needs an analog/axis variant now (for a
  hypothetical Labyrinth-style directional-but-continuous input) or
  whether the existing discrete `:LEFT`/`:RIGHT`/etc. vocabulary is
  sufficient for every currently-planned table -- leaning toward
  deferring this until a real consumer needs analog input.
- Which table becomes the first real retrofit -- Hearts is the natural
  candidate given it already has four seats, but not committing without
  confirming.

Not implemented. This is the architecture; scoping the first real PR
(seat struct + Hearts retrofit, most likely) is the next step once this
direction is confirmed.
