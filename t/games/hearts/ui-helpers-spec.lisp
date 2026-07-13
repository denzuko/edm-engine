(in-package :edm-engine/games/hearts/tests)
(in-suite :edm-engine-hearts)

(test target-player-left-right-across-none
  (is (= 1 (target-player 0 :left)))
  (is (= 3 (target-player 0 :right)))
  (is (= 2 (target-player 0 :across)))
  (is (= 0 (target-player 0 :none))))

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
