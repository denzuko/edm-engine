(in-package :edm-engine/cards)

;;; Card = (rank . suit). Rank 2-14 (11=J 12=Q 13=K 14=A). Suit keyword.
;;; Generic to any 52-card-deck game — Hearts was the first consumer,
;;; not the only intended one; a future Solitaire/Blackjack/etc. reuses
;;; this instead of redefining it.

(defun make-deck ()
  (loop for suit in '(:clubs :diamonds :hearts :spades)
        append (loop for rank from 2 to 14 collect (cons rank suit))))

(defun shuffled-deck (seed)
  (let ((rng (sb-ext:seed-random-state seed))
        (vec (coerce (make-deck) 'vector)))
    (loop for i from (1- (length vec)) downto 1
          do (rotatef (aref vec i) (aref vec (random (1+ i) rng))))
    (coerce vec 'list)))

(defparameter +suit-glyph+ '((:clubs . "♣") (:diamonds . "♦") (:hearts . "♥") (:spades . "♠")))
(defparameter +rank-glyph+ '((11 . "J") (12 . "Q") (13 . "K") (14 . "A")))

(defun card-string (card)
  (format nil "~A~A" (or (cdr (assoc (car card) +rank-glyph+)) (car card))
          (cdr (assoc (cdr card) +suit-glyph+))))
