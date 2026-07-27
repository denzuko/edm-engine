(in-package :edm-engine/games/hearts)

;;; MAKE-DECK/SHUFFLED-DECK/CARD-STRING/DEAL-HANDS/TRICK-WINNER-INDEX
;;; all live in EDM-ENGINE/CARDS now — generic to any (trick-taking)
;;; card game, not Hearts-specific, inherited here via this package's
;;; own (:USE :EDM-ENGINE/CARDS). LEGAL-PLAYS stays Hearts' own name
;;; and signature (existing callers depend on the &KEY shape) but now
;;; composes two separable, generic CARDS primitives instead of
;;; hand-rolling both a follow-suit rule and a suit-broken-lead
;;; restriction as one function.

(defun card-points (card)
  (cond
    ((eq (cdr card) :hearts) 1)
    ((equal card (cons 12 :spades)) 13)
    (t 0)))

(defun pass-direction-for-round (round)
  (nth (mod (1- round) 4) '(:left :right :across :none)))

(declaim (ftype (function (list &key (:led-suit t) (:hearts-broken t) (:leading-p t)) list)
                legal-plays))
(defun legal-plays (hand &key led-suit hearts-broken leading-p)
  "HAND is a list of cards. LED-SUIT is the trick's led suit (NIL if
none led yet / this play IS the lead). LEADING-P is T if this play
would lead the trick. Composes EDM-ENGINE/CARDS:SUIT-BROKEN-LEAD-
RESTRICTION (Hearts' own :HEARTS as the restricted suit) and
EDM-ENGINE/CARDS:FOLLOW-SUIT-LEGAL-PLAYS — the two generic halves of
what used to be one, Hearts-only function."
  (if leading-p
      (suit-broken-lead-restriction hand :hearts hearts-broken)
      (follow-suit-legal-plays hand led-suit)))
