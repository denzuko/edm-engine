(in-package :edm-engine/games/hearts/tests)
(in-suite :edm-engine-hearts)

;;; TARGET-PLAYER is generic (EDM-ENGINE/CORE) now — its own coverage
;;; lives in t/seats-spec.lisp, not duplicated here.

(test toggle-pass-selection-adds-up-to-three-then-stops
  (let ((game (make-hearts-game :seed 1 :round 1)))
    (dolist (c (subseq (first (hearts-game-hands game)) 0 4))
      (toggle-pass-selection game c))
    (is (= 3 (length (hearts-game-pass-selection game))))))

(test toggle-pass-selection-removes-if-already-selected
  (let* ((game (make-hearts-game :seed 1 :round 1))
         (card (first (first (hearts-game-hands game)))))
    (toggle-pass-selection game card)
    (toggle-pass-selection game card)
    (is (null (hearts-game-pass-selection game)))))

(test execute-pass-moves-13-cards-still-per-hand-and-clears-passing-phase
  (let ((game (make-hearts-game :seed 1 :round 1)))
    (setf (hearts-game-pass-selection game) (subseq (first (hearts-game-hands game)) 0 3))
    (execute-pass game)
    (is (eq :playing (hearts-game-phase game)))
    (is (every (lambda (h) (= 13 (length h))) (hearts-game-hands game)))
    (is (find (cons 2 :clubs) (nth (hearts-game-leader game) (hearts-game-hands game)) :test #'equal))))

(test execute-pass-round-4-would-be-a-no-op-direction
  "Round 4 is :none — MAKE-HEARTS-GAME already skips passing for it, so
this just confirms the direction lookup used by EXECUTE-PASS agrees."
  (is (eq :none (pass-direction-for-round 4))))

;;; #64's own Hearts pilot retrofit — TRY-HEARTS-GAME-PASS-EXECUTED is
;;; DEFORCHESTRATION's own generated function, replacing render.lisp's
;;; own manual guard-check + EXECUTE-PASS-call + BUS-PUSH trio with one
;;; call. EXECUTE-PASS itself stays completely untouched (still sets
;;; :PLAYING itself, per the test above, which passes unmodified) — the
;;; pilot's own stated constraint, not a design preference: the macro's
;;; own phase-set is redundant here, but harmless, and preserving
;;; EXECUTE-PASS as a whole, already-tested unit matters more than
;;; avoiding one redundant SETF.

(test hearts-pass-selection-complete-p-true-only-at-exactly-three
  (let ((game (make-hearts-game :seed 1 :round 1)))
    (is (not (hearts-pass-selection-complete-p game)))
    (dolist (c (subseq (first (hearts-game-hands game)) 0 3))
      (toggle-pass-selection game c))
    (is (hearts-pass-selection-complete-p game))))

(test try-hearts-game-pass-executed-does-nothing-with-fewer-than-3-selected
  (let ((game (make-hearts-game :seed 1 :round 1)))
    (toggle-pass-selection game (first (first (hearts-game-hands game))))
    (is (eq nil (try-hearts-game-pass-executed game)))
    (is (eq :passing (hearts-game-phase game)))))

(test try-hearts-game-pass-executed-transitions-and-fires-when-3-selected
  (let ((game (make-hearts-game :seed 1 :round 1)))
    (setf (hearts-game-pass-selection game) (subseq (first (hearts-game-hands game)) 0 3))
    (is (eq t (try-hearts-game-pass-executed game)))
    (is (eq :playing (hearts-game-phase game)))
    (is (every (lambda (h) (= 13 (length h))) (hearts-game-hands game)))))

(test try-hearts-game-pass-executed-pushes-its-own-bus-event
  (loop while (nth-value 1 (edm-engine:bus-try-pop edm-engine:*engine-bus* :audio)))
  (let ((game (make-hearts-game :seed 1 :round 1)))
    (setf (hearts-game-pass-selection game) (subseq (first (hearts-game-hands game)) 0 3))
    (try-hearts-game-pass-executed game)
    (multiple-value-bind (event received-p)
        (edm-engine:bus-try-pop edm-engine:*engine-bus* :audio)
      (is-true received-p)
      (is (equal '(:game :hearts :cue :pass-executed) event)))))

(test move-hand-cursor-wraps-within-hand-length
  (let ((game (make-hearts-game :seed 1 :round 4)))
    (move-hand-cursor game -1 13)
    (is (= 12 (hearts-game-cursor game)))
    (move-hand-cursor game 1 13)
    (is (= 0 (hearts-game-cursor game)))))

(test advance-round-deals-fresh-hands-and-carries-scores-forward
  (let ((game (make-hearts-game :seed 1 :round 4)))
    (setf (hearts-game-scores game) (list 10 20 30 40))
    (advance-round game)
    (is (= 5 (hearts-game-round game)))
    (is (equal '(10 20 30 40) (hearts-game-scores game)))
    (is (equal '(0 0 0 0) (hearts-game-round-points game)))))
