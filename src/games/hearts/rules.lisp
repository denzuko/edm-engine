(in-package :edm-engine/games/hearts)

;;; MAKE-DECK/SHUFFLED-DECK/CARD-STRING now live in EDM-ENGINE/CARDS —
;;; generic to any card game, not Hearts-specific. Re-exported below so
;;; existing callers of EDM-ENGINE/GAMES/HEARTS: don't need to know the
;;; split.

(defun deal-hands (deck)
  "Splits DECK (52 cards) into 4 hands of 13, in dealing order."
  (loop for i from 0 below 4
        collect (loop for j from i below 52 by 4 collect (nth j deck))))

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
would lead the trick."
  (cond
    (leading-p
     (if (or hearts-broken (every (lambda (c) (eq (cdr c) :hearts)) hand))
         hand
         (or (remove :hearts hand :key #'cdr) hand)))
    (t
     (let ((following (remove led-suit hand :key #'cdr :test-not #'eq)))
       (or following hand)))))

(declaim (ftype (function (list keyword) fixnum) trick-winner-index))
(defun trick-winner-index (trick led-suit)
  "TRICK is a list of 4 cards in play order. Returns the 0-based index
of the highest-ranked card matching LED-SUIT — off-suit cards, however
high their rank, never win."
  (let ((best-index 0) (best-rank -1))
    (loop for card in trick
          for i from 0
          when (and (eq (cdr card) led-suit) (> (car card) best-rank))
            do (setf best-index i best-rank (car card)))
    best-index))
