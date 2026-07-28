(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

;;; Generic "progression" — per direct correction: Queens' own LEVEL
;;; and Hearts'/Yahtzee's own ROUND are the same abstract shape (a
;;; numbered counter starting at 1, advancing) under two different,
;;; independently-invented game vocabularies, not two genuinely
;;; different concepts. AT-FINAL-PROGRESSION-P is the one piece
;;; already, genuinely duplicated in spirit — Queens' own hand-rolled
;;; (>= LEVEL +QUEENS-LEVEL-COUNT+) check — with a real generic shape
;;; underneath it (any numbered progression, capped or not).
;;;
;;; Deliberately NOT generalizing an "advance the counter" function
;;; here too: Hearts' own round-progression has no cap at all — it
;;; ends on a score threshold (GAME-OVER-P), not a round count —
;;; forcing that into a capped-progression shape would misrepresent a
;;; real, honest difference between the two games rather than unify a
;;; genuine similarity. Only the piece that's actually the same
;;; (checking whether a counter has reached a known cap) is lifted.

(declaim (ftype (function (fixnum fixnum) boolean) at-final-progression-p))
(defun at-final-progression-p (current max)
  "True once CURRENT has reached (or passed) MAX — the shared shape
behind Queens' own 'is this the final level' check, generalized to
any capped, numbered progression (a level, a bounded round count, a
wave number)."
  (>= current max))
