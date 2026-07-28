(defpackage :edm-engine/cards/tests
  (:use :cl :fiveam :edm-engine/cards))
(in-package :edm-engine/cards/tests)

(def-suite :edm-engine-cards)
(in-suite :edm-engine-cards)

;;; Generic to any trick-taking card game — Hearts was the first
;;; consumer, not the only intended one (per direct instruction:
;;; trick-taking games are a future release pack, and Boss Monster's
;;; own card mechanics have trick-taking-like structure too). Moved
;;; from src/games/hearts/rules.lisp, where these lived as if they
;;; were Hearts-specific despite being standard, well-known mechanics
;;; shared across Spades/Bridge/Euchre/Hearts, not speculative
;;; invention of a "maybe generic" shape.

(test deal-hands-splits-deck-into-n-hands-of-given-size
  "Generalized from Hearts' own hardcoded 4-players/13-cards — takes
both as parameters, since a future trick-taking game may have a
different table size or hand size."
  (let ((hands (deal-hands (make-deck) 4 13)))
    (is (= 4 (length hands)))
    (is (every (lambda (h) (= 13 (length h))) hands))
    (is (= 52 (length (remove-duplicates (apply #'append hands) :test #'equal))))))

(test deal-hands-works-for-a-different-table-and-hand-size
  "Not hardcoded to Hearts' own 4/13 — a 3-player, 17-card deal from
a 51-card deck (one card short of even, deliberately, to confirm this
doesn't require an exact fit)."
  (let ((hands (deal-hands (subseq (make-deck) 0 51) 3 17)))
    (is (= 3 (length hands)))
    (is (every (lambda (h) (= 17 (length h))) hands))))

(test trick-winner-index-highest-card-of-led-suit-wins
  (let ((trick (list (cons 5 :clubs) (cons 12 :clubs) (cons 2 :hearts) (cons 9 :clubs))))
    (is (= 1 (trick-winner-index trick :clubs)))))

(test trick-winner-index-ignores-cards-not-in-led-suit
  "An ace of a different suit never wins the trick, no matter how high."
  (let ((trick (list (cons 3 :diamonds) (cons 14 :spades) (cons 9 :diamonds))))
    (is (= 2 (trick-winner-index trick :diamonds)))))

(test follow-suit-legal-plays-must-follow-suit-if-possible
  "The generic half of Hearts' own LEGAL-PLAYS — following a trick
already in progress, with no restricted-suit lead concept at all
(that's a separate, genuinely different primitive below)."
  (let ((hand (list (cons 5 :hearts) (cons 9 :clubs) (cons 2 :spades))))
    (is (equal (list (cons 9 :clubs))
               (follow-suit-legal-plays hand :clubs)))))

(test follow-suit-legal-plays-any-card-if-void-in-led-suit
  (let ((hand (list (cons 5 :hearts) (cons 9 :clubs))))
    (is (equal hand (follow-suit-legal-plays hand :diamonds)))))

(test suit-broken-lead-restriction-cannot-lead-restricted-suit-until-broken
  "Generalized from Hearts' own 'can't lead hearts until broken' —
Spades has the identical mechanic for its own trump suit, so this
takes the restricted suit as a parameter rather than hardcoding
:HEARTS."
  (let ((hand (list (cons 5 :hearts) (cons 9 :clubs))))
    (is (equal (list (cons 9 :clubs))
               (suit-broken-lead-restriction hand :hearts nil)))))

(test suit-broken-lead-restriction-may-lead-restricted-suit-once-broken
  (let ((hand (list (cons 5 :hearts) (cons 9 :clubs))))
    (is (equal hand (suit-broken-lead-restriction hand :hearts t)))))

(test suit-broken-lead-restriction-an-all-restricted-suit-hand-may-lead-it-unbroken
  "If the restricted suit is all the player has, they must be allowed
to lead it — matching Hearts' own existing rule for an all-hearts
hand."
  (let ((hand (list (cons 5 :hearts) (cons 9 :hearts))))
    (is (equal hand (suit-broken-lead-restriction hand :hearts nil)))))

;;; TOGGLE-SELECTION — the generic half of Hearts' own TOGGLE-PASS-
;;; SELECTION: "toggle membership in a selection, up to N items."
;;; Not card-specific at all — the same shape as any "select up to N
;;; from a hand" UI (dominoes tiles, Boss Monster room cards). Pure —
;;; returns the new selection list, doesn't mutate anything; each
;;; game's own wrapper does the SETF.

(test toggle-selection-adds-an-unselected-item
  (is (equal '(:a) (toggle-selection :a nil 3))))

(test toggle-selection-removes-an-already-selected-item
  (is (equal nil (toggle-selection :a '(:a) 3))))

(test toggle-selection-stops-adding-once-max-count-is-reached
  (is (equal '(:c :b :a) (toggle-selection :d '(:c :b :a) 3))))

;;; START-CARD-TWEEN / CARD-DRAW-POSITION — item 3 of the systematic
;;; catalog (6b91931): pure card+tween plumbing, nothing Hearts-
;;; specific about "animate a card from A to B, draw its tweened
;;; position while running or the default once finished." Made
;;; genuinely pure and testable here — unlike Hearts' own original
;;; (which called RAYLIB:GET-TIME internally, an I/O dependency with
;;; no test coverage) — by taking NOW explicitly, matching TWEEN-
;;; POSITION/TWEEN-FINISHED-P's own existing (TWEEN NOW) convention.
;;; Each game still owns its own *CARD-TWEENS* hash table (a defvar
;;; in its own render.lisp, same as *AI-CLOCK*/*THEME-SOUND*) — not
;;; lifted into shared global state, just the pure functions that
;;; operate on whichever table a caller passes in.

(test start-card-tween-then-card-draw-position-returns-the-start-point-immediately
  (let ((tweens (make-hash-table :test #'equal))
        (card (cons 5 :hearts)))
    (start-card-tween tweens card 10.0 20.0 100.0 200.0 0.0d0 0.5d0)
    (multiple-value-bind (x y) (card-draw-position tweens card 999.0 999.0 0.0d0)
      (is (= 10.0 x))
      (is (= 20.0 y)))))

(test card-draw-position-mid-tween-is-between-start-and-end
  (let ((tweens (make-hash-table :test #'equal))
        (card (cons 5 :hearts)))
    (start-card-tween tweens card 0.0 0.0 100.0 0.0 0.0d0 1.0d0)
    (multiple-value-bind (x y) (card-draw-position tweens card 999.0 999.0 0.5d0)
      (declare (ignore y))
      (is (< 0.0 x 100.0)))))

(test card-draw-position-after-the-tween-finishes-returns-the-default
  (let ((tweens (make-hash-table :test #'equal))
        (card (cons 5 :hearts)))
    (start-card-tween tweens card 0.0 0.0 100.0 0.0 0.0d0 0.5d0)
    (multiple-value-bind (x y) (card-draw-position tweens card 42.0 43.0 10.0d0)
      (is (= 42.0 x))
      (is (= 43.0 y)))))

(test card-draw-position-for-a-never-tweened-card-returns-the-default
  (let ((tweens (make-hash-table :test #'equal)))
    (multiple-value-bind (x y) (card-draw-position tweens (cons 9 :clubs) 7.0 8.0 0.0d0)
      (is (= 7.0 x))
      (is (= 8.0 y)))))

;;; LOWEST-RANK-CARD / HIGHEST-N-CARDS — item 6 of the systematic
;;; catalog (6b91931): the reusable naive-AI heuristic shapes behind
;;; Hearts' own AI-CHOOSE-PLAY ("play the lowest legal card") and
;;; AI-CHOOSE-PASS ("discard your N highest cards") — generic to any
;;; trick-taking game's own naive strategy, not Hearts-specific logic.
;;; Hearts' own functions keep deciding WHICH cards are eligible
;;; (LEGAL-PLAYS, the whole hand) — these two only pick from within
;;; an already-decided candidate list, the genuinely reusable part.

(test lowest-rank-card-picks-the-lowest-rank-regardless-of-suit
  (is (equal (cons 2 :clubs)
             (lowest-rank-card (list (cons 9 :hearts) (cons 2 :clubs) (cons 14 :spades))))))

(test highest-n-cards-returns-the-n-highest-rank-cards
  (is (equal (list (cons 14 :spades) (cons 9 :hearts))
             (highest-n-cards (list (cons 2 :clubs) (cons 9 :hearts) (cons 14 :spades)) 2))))

(test highest-n-cards-with-n-greater-than-the-hand-returns-the-whole-hand
  (is (= 2 (length (highest-n-cards (list (cons 2 :clubs) (cons 9 :hearts)) 5)))))
