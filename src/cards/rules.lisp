(in-package :edm-engine/cards)

(declaim (optimize (speed 3) (safety 3)))

;;; Generic to any trick-taking card game — Hearts was the first
;;; consumer, not the only intended one (trick-taking games are a
;;; named future release pack; Boss Monster's own card mechanics have
;;; trick-taking-like structure too). Moved from
;;; src/games/hearts/rules.lisp, where DEAL-HANDS and TRICK-WINNER-
;;; INDEX lived as if Hearts-specific despite being standard, shared
;;; mechanics (Spades/Bridge/Euchre all use the same "highest card of
;;; the led suit wins" rule) — and where LEGAL-PLAYS bundled a
;;; genuinely generic "follow suit if possible" rule together with a
;;; genuinely Hearts-specific "can't lead this suit until broken"
;;; rule as one function, when they're two separable primitives
;;; (Spades has its own suit-broken-lead restriction on trump, for
;;; instance — the same shape, a different suit).

(defun deal-hands (deck player-count hand-size)
  "Splits DECK into PLAYER-COUNT hands of HAND-SIZE, in dealing order
(round-robin — player 0 gets card 0, player 1 gets card 1, ...).
Generalized from Hearts' own hardcoded 4-players/13-cards; a future
trick-taking game may have a different table or hand size."
  (loop for i from 0 below player-count
        collect (loop for j from i below (* player-count hand-size) by player-count
                      collect (nth j deck))))

(declaim (ftype (function (list keyword) fixnum) trick-winner-index))
(defun trick-winner-index (trick led-suit)
  "TRICK is a list of cards in play order. Returns the 0-based index
of the highest-ranked card matching LED-SUIT — off-suit cards, however
high their rank, never win."
  (let ((best-index 0) (best-rank -1))
    (loop for card in trick
          for i from 0
          when (and (eq (cdr card) led-suit) (> (car card) best-rank))
            do (setf best-index i best-rank (car card)))
    best-index))

(defun follow-suit-legal-plays (hand led-suit)
  "The generic half of a trick-taking legal-play rule: if HAND has any
card matching LED-SUIT, only those are legal; otherwise the whole hand
is legal (a genuine void in the led suit). No restricted-suit lead
concept at all — that's SUIT-BROKEN-LEAD-RESTRICTION, a separate,
composable primitive, not folded into this one."
  (let ((following (remove led-suit hand :key #'cdr :test-not #'eq)))
    (or following hand)))

(defun suit-broken-lead-restriction (hand restricted-suit broken-p)
  "The generic half of Hearts' 'can't lead hearts until broken' rule
— Spades has the identical mechanic on its own trump suit, hence
RESTRICTED-SUIT as a parameter rather than hardcoding :HEARTS. If
BROKEN-P, or HAND is entirely RESTRICTED-SUIT (nothing else to lead),
the whole hand may lead; otherwise RESTRICTED-SUIT cards are excluded
from what may lead."
  (if (or broken-p (every (lambda (c) (eq (cdr c) restricted-suit)) hand))
      hand
      (or (remove restricted-suit hand :key #'cdr) hand)))

(defun toggle-selection (item selection max-count)
  "The generic half of Hearts' own TOGGLE-PASS-SELECTION: toggle
ITEM's membership in SELECTION, capped at MAX-COUNT. Pure — returns
the new selection list, doesn't mutate anything; each game's own
wrapper does the SETF. Not card-specific — the same shape as any
'select up to N from a hand' UI (dominoes tiles, Boss Monster room
cards)."
  (if (member item selection :test #'equal)
      (remove item selection :test #'equal)
      (if (< (length selection) max-count)
          (cons item selection)
          selection)))

;;; START-CARD-TWEEN / CARD-DRAW-POSITION — pure card+tween plumbing,
;;; nothing Hearts-specific about "animate a card from A to B, draw
;;; its tweened position while running or the default once finished."
;;; TWEENS is a hash table (CARD -> TWEEN) each game owns as its own
;;; state (a defvar in its own render.lisp, same as *AI-CLOCK*/
;;; *THEME-SOUND*) — not lifted into shared global state, just the
;;; pure functions passed whichever table a caller owns. NOW is
;;; explicit (matching TWEEN-POSITION/TWEEN-FINISHED-P's own existing
;;; convention) rather than calling RAYLIB:GET-TIME internally —
;;; Hearts' own original did that, an I/O dependency with no test
;;; coverage; genuinely pure and testable here instead.

(defun start-card-tween (tweens card start-x start-y end-x end-y now duration)
  (setf (gethash card tweens)
        (edm-engine:make-tween :start-x (float start-x 1.0) :start-y (float start-y 1.0)
                                :end-x (float end-x 1.0) :end-y (float end-y 1.0)
                                :start-time now :duration duration)))

(defun card-draw-position (tweens card default-x default-y now)
  "Returns (values x y) — CARD's tweened position while its animation
in TWEENS is still running, or DEFAULT-X/Y once it's finished (or was
never tweened, e.g. a hand card that hasn't moved)."
  (let ((tw (gethash card tweens)))
    (if (and tw (not (edm-engine:tween-finished-p tw now)))
        (edm-engine:tween-position tw now)
        (values (float default-x 1.0) (float default-y 1.0)))))
