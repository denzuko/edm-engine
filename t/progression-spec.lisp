(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; Generic "progression" concept — per direct correction: Queens'
;;; own LEVEL and Hearts'/Yahtzee's own ROUND are the same abstract
;;; shape (a numbered counter starting at 1, advancing, potentially
;;; capped) under two different, game-invented names. AT-FINAL-
;;; PROGRESSION-P is the one piece already genuinely duplicated
;;; (Queens' own QUEENS-FINAL-LEVEL-P) with a real second consumer
;;; waiting (Hearts' own round-progression has no cap at all today,
;;; ending on a score threshold instead — a real, honest difference,
;;; not papered over by forcing a cap where none exists).

(test at-final-progression-p-false-before-the-cap
  (is (not (at-final-progression-p 3 25))))

(test at-final-progression-p-true-at-the-cap
  (is (at-final-progression-p 25 25)))

(test at-final-progression-p-true-past-the-cap
  "Shouldn't matter if a caller somehow advances past the cap in one
step — still true, not requiring an exact match."
  (is (at-final-progression-p 30 25)))

;;; ADVANCE-OR-TERMINATE — found via the same full-audit treatment
;;; #64's own pilot got, applied to the level/round progression shape
;;; specifically: Hearts' own round-over transition and Queens' own
;;; level-advance transition independently arrived at the identical
;;; outer shape — a DEFOUTCOME call producing either a 'keep going'
;;; sentinel or a terminal status, then either advancing (resetting
;;; per-progression state via each game's own callback) or setting
;;; the terminal status. Proven against both real consumers at once,
;;; not generalized from one.

(test advance-or-terminate-calls-advance-fn-and-returns-nil-when-keep-going
  (let ((advanced nil))
    (is (eq nil (advance-or-terminate :playing :playing (lambda () (setf advanced t)))))
    (is-true advanced)))

(test advance-or-terminate-does-not-call-advance-fn-when-terminal
  (let ((advanced nil))
    (is (eq :won (advance-or-terminate :won :playing (lambda () (setf advanced t)))))
    (is (not advanced))))
