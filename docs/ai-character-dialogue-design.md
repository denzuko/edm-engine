# AI character & dialogue system — named opponents, not bare difficulty tiers

Status: design proposal, not implemented. Corrects a real gap between
what's built and what this project's own reference material has
specified since its earliest screenshots -- not a new feature request,
a description of what the avatar/difficulty screen was always supposed
to be.

## The gap, stated plainly

The current difficulty-selection screen (`arcade.lisp`) offers three
generic tiers -- novice/standard/expert, pawn/knight/queen glyphs, no
identity beyond the tier itself. Hoyle's Book of Games Volume 1 (Sierra
On-Line, Ken Williams) -- present in this project's files since its
earliest screenshots, referenced explicitly earlier this session as the
structural model for this screen -- shows something categorically
different: selecting a Cribbage opponent surfaces a full cast of named
characters (Larry Laffer among them, with his own self-introduction
dialogue and a stated "CRIBBAGE SKILL: AMATEUR"), grouped under a
banner ("The Not-So-Serious Players"), each with a distinct portrait,
voice, and evident personality. Skill was never meant to be separable
from a named character's identity and tone -- this engine's tier picker
is a placeholder that never got upgraded to what the reference actually
specifies, not a deliberate simplification.

This also directly changes #39's seat design: a seat's AI slot should
hold a character (skill + play style + voice bundled as one identity),
not a bare difficulty keyword. `docs/local-multiplayer-design.md`
already updated to reflect this.

## 1. Character roster -- shared across tables, not per-game

Hoyle's own screen groups its cast under named banners ("The Not-So-
Serious Players") that recur across multiple games in the compilation,
not a unique roster invented per table. Matching that: a single,
engine-level cast, not four separate rosters for four separate games.

```lisp
(defstruct ai-character
  (id nil :type keyword)              ; e.g. :marcus
  (display-name "" :type string)
  (skill-tier :novice :type (member :novice :standard :expert))  ; feeds
                                       ; #3's remaining Screamer-lookahead
                                       ; scope -- search depth/heuristic
                                       ; weighting, not redesigned here
  (play-style :balanced :type keyword)  ; :aggressive / :conservative /
                                         ; :balanced / etc. -- influences
                                         ; heuristic decision weighting
                                         ; within a skill tier, not just
                                         ; "harder" vs. "easier"
  (avatar-glyph "" :type string)      ; this engine's own vector glyph
                                       ; language (per the earlier,
                                       ; explicit "don't copy the EGA
                                       ; pixel art" correction) -- a
                                       ; character identity, not a
                                       ; literal portrait
  (voice nil))                        ; a DIALOGUE-VOICE, see below
```

**Play style is a real, separate axis from skill tier**, matching
Hoyle's own characters (Larry's "AMATEUR" skill is paired with an
evident personality that isn't just "plays worse") -- two `:novice`
characters could play differently from each other (one folds early
under pressure, one bluffs), not just "both play badly." This is the
concrete shape #3's remaining scope should target: distinct behavior
per character, not a single heuristic tuned to three difficulty knobs.

## 2. Dialogue content -- taunts, wins, losses, table chatter

```lisp
(defstruct dialogue-voice
  (taunts nil :type list)      ; list of strings, shown on landing a strong play
  (wins nil :type list)
  (losses nil :type list)
  (chatter nil :type list))    ; idle table talk, low-frequency
```

Line selection is random-with-no-immediate-repeat within a category
(pick uniformly, avoid the same line twice in a row) -- simple, matches
the "don't over-engineer" discipline already established for this
codebase, no need for a Markov-chain dialogue generator or similar for
a handful of lines per character per category.

## 3. Trigger mechanism -- bus events, not inline dialogue calls

Connects directly to the already-designed event-bus pattern (#37's VFX
pipeline, #21/#22's CSP restoration) rather than inventing a separate
mechanism -- game logic pushes a semantic event, a dialogue consumer
(same shape as the VFX processor: drains a topic once per frame, main
thread) decides whether an AI character present at the table has
something to say:

```lisp
;; in GAME-UPDATE, when something dialogue-worthy happens
(bus-push *engine-bus* :dialogue (list :trick-won seat-index))
(bus-push *engine-bus* :dialogue (list :round-lost seat-index))
```

A per-table event vocabulary (Hearts: `:trick-won`, `:shot-the-moon`,
`:round-lost`; Yahtzee: `:yahtzee-rolled`, `:category-scored`; future
tables define their own) maps to which `DIALOGUE-VOICE` category a line
gets drawn from -- table-specific event names, but the same generic
consumer and the same `AI-CHARACTER`/`DIALOGUE-VOICE` structures across
every table, matching the roster being shared rather than per-game.

## 4. Display -- composes the layout/widget work already scoped, not new

A dialogue line needs a bordered text box (matching Hoyle's yellow
dialogue box structurally, not visually -- this engine's own chrome/
panel styling, not a copied color scheme), positioned near the
speaking character's seat, using `WRAP-TEXT-LINES` (already built,
verified correct this session against real edge cases) and the UI font
register (`draw-ui-text`, already built). This is composition of #36's
layout primitives and #38's widget system, not a new rendering path --
a `DIALOGUE-BOX` would be a natural addition to #38's widget catalog
alongside `LIST-WIDGET`/`GRID-WIDGET`/`CARD-HAND-WIDGET`.

## Cross-references

Corrects #39's seat design directly (already updated). Is the concrete
shape for #3's remaining scope (play style as a real axis, not just
search depth). Is the properly-specified version of #12's "opponent
dialogue/personality" line item. Composes #36 (layout) and #38
(widgets) rather than inventing new positioning/rendering. Character
override *is* #37's stylesheet cascade mechanism, not a parallel
system -- a character is a selector namespace, same as `(:card :back)`.
Gives #8 a real, named second consumer (conditional behavior adjustment
via gamerule facts), not just theoretical justification. Uses the
event-bus shape #21/#22 already establish for dialogue triggering.

## 5. Global baseline, per-table override -- the same cascade as #37, not a separate mechanism

A character's definition above (skill tier, play style, voice) is a
*global baseline*, not a fixed, table-blind constant. Correction to
this doc's own earlier framing: a character shouldn't need a
completely separate override mechanism from #37's stylesheet cascade --
it should *be* cascadable data, the same selector-plus-last-wins
pattern, not a bespoke second system:

```lisp
(defcharacter-baseline :larry
  :skill-tier :novice
  :play-style :flirtatious-chatter
  :voice (dialogue-voice ...))

;; per-table override -- same DEFSTYLESHEET-style selector mechanism as #37,
;; not a new pattern. Unspecified attributes fall back to the baseline.
(defcharacter-override (:character :larry :table :hearts)
  :voice (dialogue-voice :taunts (...)))   ; Hearts-specific lines
                                            ; (references shooting-the-moon,
                                            ; a Hearts-only event) --
                                            ; skill-tier/play-style not
                                            ; overridden here, inherited
                                            ; from baseline
```

This is genuinely the same shape as a game pack overriding `(:selector
(:card :back) ...)` in #37 -- a character is just another cascadable
selector namespace, resolved once (at table-load time, not per frame)
into a flat effective-character table, matching #37's own performance
discipline exactly.

### "Gamerule facts" -- the real second consumer #8 was waiting for

Simple attribute override (above) covers "Larry's Hearts dialogue is
different from his baseline." It doesn't cover *conditional* behavior
adjustment -- "if this table has house-rule X active, an aggressive
character's risk tolerance should shift" -- which is a genuine
fact-plus-rule query, not a static override. This is exactly the shape
#8 (Datalog/Prolog ruleset branch) was scoped for and has been waiting
on a real consumer for: persistent facts (a table's active house rules,
a character's play-style) queried by rules (how should this character's
decision-making adjust given those facts), not a one-shot search the
way Screamer is used for Queens' board generation.

Illustrative only, not committing to #8's eventual syntax (that's its
own scope):
```lisp
;; once #8's branch exists
(assert-fact (:table-rule :hearts :no-shooting-the-moon))
(defrule (:character-behavior :risk-tolerance)
  (:when (:character-play-style ?c :aggressive) (:table-rule ?t :active))
  (:then (:adjust ?c :risk-tolerance -0.2)))
```

Not designing #8's internals here -- flagging that this system is the
concrete, real second consumer that justifies building it, the same
way Yahtzee was the real second consumer that justified the AI-timer/
difficulty-tier library existing as a shared thing rather than Hearts-
specific code.



- Whether unlockable characters (connecting to #38's easter-egg system
  -- a new character joins the roster as an unlock reward, matching
  Hoyle's large cast feeling like something to discover) are in scope
  for a first version, or whether the initial roster should just be
  fully available and unlocks apply to tables/content instead. Leaning
  toward "not in v1" -- a roster of 3-4 characters is enough to prove
  the system; unlockable characters is a real but separable idea.
- Exact size of the initial roster and who writes the dialogue content
  -- a content question, not an architecture one.
- Whether `PLAY-STYLE` should be an open keyword (any table can invent
  new styles) or a fixed enum shared across all tables -- leaning
  toward open keyword, matching how Hoyle's Book of Games characters
  clearly have per-game personality flavor even under shared skill
  tiers, but not settled here.

Not implemented. This is the architecture and the correction to #39's
seat design; scoping a first real roster (how many characters, which
table gets dialogue first) is the next step once this direction is
confirmed.
