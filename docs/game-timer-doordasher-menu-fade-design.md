# Game timer primitive, Door Dasher spec, and the title-to-menu fade fix

Status: design proposal, not implemented. Three related items from one
message, grounded in research rather than assumed: Avoid the Noid's
actual mechanics (verified via search), the referenced Game Developer
article read in full, and the current title-to-menu transition code
checked directly before designing its replacement.

## 1. Game timer primitive

Discovered as a real gap while reviewing Door Dasher's design (below),
but genuinely general-purpose -- explicitly named as translating to
chess-clock-style variants for other tables, not scoped to one game.

### One primitive, composed for both real-time countdowns and chess clocks, not two separate systems

```lisp
(defstruct game-timer
  (direction :countdown :type (member :countdown :count-up))
  (value 0.0d0 :type double-float)          ; seconds remaining (countdown)
                                             ; or elapsed (count-up) --
                                             ; DOUBLE-FLOAT throughout,
                                             ; from the start, per #31/#32's
                                             ; established lesson
  (limit nil :type (or null double-float))  ; countdown target, or
                                             ; count-up cap; NIL = unbounded
  (running-p t :type boolean))              ; pausable -- the field that
                                             ; makes chess-clock composition
                                             ; work, see below

(defun timer-update (timer dt) ...)   ; advances VALUE by DT when RUNNING-P
(defun timer-expired-p (timer) ...)   ; T if countdown hit zero or
                                       ; count-up hit LIMIT
```

**A chess clock is N of these, one active at a time -- not a third,
separate timer type.** A per-seat vector of `GAME-TIMER`s, all
`:COUNTDOWN`, each initialized to the same budget; turn-change logic
toggles `RUNNING-P` (stop the seat whose turn just ended, start the
next seat's). No new structure needed for the chess-clock case, just
composition of the same primitive #39's seat vector already provides
the natural home for.

### Connects directly to #42's real-time protocol extension, and exposes a nuance worth naming

`TIMER-UPDATE` needs `DT` every frame it's running -- exactly what
`GAME-UPDATE-REALTIME` (#42's Game & Watch protocol design) already
provides for real-time tables. But a chess-clock-equipped *turn-based*
table (a hypothetical "speed Hearts" variant) would also need `DT`
access purely for its timer, without needing the rest of the real-time
protocol (continuous position integration, collision timing). Worth
flagging as an open question for #42 rather than resolving here: should
plain `GAME-UPDATE` optionally receive `DT` too (for timer-only use, not
full real-time dispatch), or does any table needing a running clock
count as "realtime-p" regardless of whether it's otherwise turn-based?
Not deciding this now -- noting it because #42's protocol design should
account for it before implementation, not discover it partway through.

---

## 2. Door Dasher -- an Avoid the Noid clone, mechanics researched directly

Avoid the Noid (Domino's Pizza promotional tie-in, 1989, MS-DOS/C64) is
trademarked/copyrighted -- Door Dasher preserves the *mechanics*
(verified via research, not recalled from memory), not the branding,
mascot, or pizza theme.

### Verified mechanics being adapted

A player traverses a multi-floor building (the original: 30 stories)
against a countdown timer (the original: a 30-minute in-fiction limit),
avoiding hazards thrown by roaming antagonists (thrown objects,
booby-trapped interactables that are safe or lethal without warning the
first time), with a small pool of lives (the original: 5) rather than
one-hit failure. Reaching the top before time expires wins; running out
of lives or time loses.

### Theme, deliberately generic rather than reskinned mascot-for-mascot

Not a "generic pizza delivery" reskin -- a courier delivering a package/
letter through an office building, avoiding generic obstacles (falling
objects, a booby-trapped phone/intercom mechanic, roaming hazards). No
single named antagonist character required; if an antagonist is wanted,
this is a real candidate consumer for #40's existing character roster
rather than inventing a Door-Dasher-specific mascot.

### The genuinely new protocol dependency

This is the second real consumer (after the abstract Game & Watch
scoping in #42) for `GAME-UPDATE-REALTIME` -- continuous left/right/
jump movement and hazard collision detection, not discrete grid
movement. Scoping Door Dasher concretely is a real argument for
prioritizing #42's protocol extension sooner rather than later, since
it now has two named consumers instead of one abstract case.

### Reuses existing infrastructure

- **Game timer (section 1)**: the countdown is the primitive's first
  real consumer.
- **VFX (#37)**: hazard-collision feedback (screen shake on a hit,
  flash on a near-miss) is exactly what #37's event-driven effect
  pipeline is for -- arguably an even sharper proof case than Game &
  Watch's abstract scoping, since Door Dasher's whole tension is
  built on that feedback.
- **Lives**: a simple counter, not a new HP/combat system -- distinct
  from and simpler than Labyrinth's combat (#42), which is turn-based
  and narratively framed differently. Not reusing Labyrinth's combat
  design; this is a separate, smaller mechanic.

### What's new

The real-time protocol extension itself (shared scope with #42, now
with a second concrete consumer) and the floor-by-floor vertical
level structure (a new layout shape -- not a grid, not a row, a
traversable vertical sequence of rooms/floors). Everything else
(timer, VFX, lives-as-counter) composes existing or newly-scoped
primitives.

---

## 3. The title-to-menu transition -- fixing a real tone break with existing infrastructure, not new machinery

Grounded directly in the referenced article (read in full, not
skimmed): its core argument is that menus shouldn't read as a
"separate entity" from the game -- Dragon Age: Inquisition's menu
dynamically transforms into gameplay on selection rather than hard-
cutting; Mega Man X's title character is already "alive," facing the
direction play will move. Checked this engine's actual current
behavior against that standard rather than assuming the complaint:

```lisp
(defun arcade-dismiss-title (state)
  (setf (arcade-state-mode state) :main-menu))
```

Confirmed -- a one-line, single-frame hard mode switch, no transition
at all. Exactly the "lifeless, disconnected screens" problem the
article names.

### The fix uses exactly the systems already designed for this, not new machinery

**Fade**: an alpha-interpolation effect, using #37's `EFFECT-UPDATE`/
`EFFECT-FINISHED-P`/`EFFECT-APPLY` protocol (the same generalization
of `TWEEN.LISP` #37 already proposes) -- an `ALPHA-FADE` effect type
alongside the position-tween case already designed, not a new effect
system.

**Position**: "center lower paneling location" is an anchor-in-
container position, exactly #36's layout vocabulary (the same
`CENTER-WITHIN`/anchor primitives already scoped there) -- not a new
positioning concept.

**Panel styling**: the main menu's background/border should be
selector-driven via #37's stylesheet cascade (`(:selector (:panel
:main-menu) :fill ... :border ...)`), not hardcoded pixel values --
this is the concrete first real screen #11 (typography/spacing never
reached any game screen) should actually land on, since it's small,
self-contained, and exactly the kind of retrofit #36/#37 have both been
waiting to prove themselves against.

### The actual transition sequence

Title dismissal no longer jumps straight to `:MAIN-MENU`. A transient
state (matching the existing pattern of pending/pausing states already
in this engine, e.g. Hearts' `TRICK-PAUSE-UNTIL`) drives: title
elements fade out (alpha effect) while simultaneously the main menu
panel fades in, positioned via the center-lower anchor, arriving at
full opacity before input is accepted -- avoiding the jarring instant
swap while not blocking the player indefinitely either. Once the fade
effects report `EFFECT-FINISHED-P`, mode becomes `:MAIN-MENU` for real,
matching how every other mode transition in this engine already works.

### Cross-references

Uses #37's effect protocol directly (a second real consumer for the
generalized `TWEEN`, alongside VFX itself). Uses #36's anchor
positioning. Is the concrete first retrofit #11 has been waiting for.

---

Not implemented. Door Dasher and the menu-fade fix both give #42's
real-time protocol and #37's effect/style pipeline concrete, named
second consumers respectively -- worth weighing that when sequencing
what gets built next, since both are currently designed but unproven
against any real table or screen.
