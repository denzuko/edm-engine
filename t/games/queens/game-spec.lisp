(in-package :edm-engine/games/queens/tests)
(in-suite :edm-engine-queens)

(test make-queens-game-starts-at-level-1-with-a-generated-board
  (let ((game (make-queens-game)))
    (is (= 1 (queens-game-level game)))
    (is (= 4 (queens-board-size (queens-game-board game))))
    (is (eq :playing (queens-game-status game)))
    (is (= 0 (queens-game-score game)))))

(test toggle-queen-places-then-removes
  (let ((game (make-queens-game)))
    (toggle-queen game 0 0)
    (is (member (cons 0 0) (queens-game-placed game) :test #'equal))
    (toggle-queen game 0 0)
    (is (not (member (cons 0 0) (queens-game-placed game) :test #'equal)))))

(test toggle-queen-does-nothing-once-game-is-won
  (let ((game (make-queens-game :level 25)))
    (setf (queens-game-status game) :won)
    (toggle-queen game 0 0)
    (is (null (queens-game-placed game)))))

(test placing-the-generated-solution-advances-to-the-next-level
  (let* ((game (make-queens-game :level 1))
         (board (queens-game-board game)))
    (loop for row from 0
          for col in (queens-board-placement board)
          do (toggle-queen game row col))
    (is (= 2 (queens-game-level game)))
    (is (eq :playing (queens-game-status game)))
    (is (null (queens-game-placed game)) "next level starts with an empty board")))

(test placing-the-solution-on-the-final-level-wins-the-whole-campaign
  (let* ((game (make-queens-game :level 25))
         (board (queens-game-board game)))
    (loop for row from 0
          for col in (queens-board-placement board)
          do (toggle-queen game row col))
    (is (eq :won (queens-game-status game)))))

(test an-invalid-full-placement-does-not-advance-the-level
  "Same row twice (5 placements on a 4x4 board can't happen — use an
adjacent-queens violation instead): place the generated solution's
first two queens, but swap them into adjacent-touching positions."
  (let* ((game (make-queens-game :level 1)))
    ;; deliberately invalid: two queens in the same column
    (toggle-queen game 0 0)
    (toggle-queen game 1 0)
    (toggle-queen game 2 1)
    (toggle-queen game 3 2)
    (is (eq :playing (queens-game-status game)))
    (is (= 1 (queens-game-level game)))))

(test score-accumulates-across-level-advances
  (let* ((game (make-queens-game :level 1))
         (board (queens-game-board game)))
    (is (= 0 (queens-game-score game)))
    (loop for row from 0
          for col in (queens-board-placement board)
          do (toggle-queen game row col))
    (is (> (queens-game-score game) 0))))

(test queens-game-points-for-level-scales-with-board-size
  (is (< (queens-game-points-for-level 1) (queens-game-points-for-level 25))))

;;; GAME-OUTCOME / GAME-SCORE protocol methods

(test queens-game-outcome-nil-while-playing
  (let ((game (make-queens-game)))
    (is (null (edm-engine:game-outcome game)))))

(test queens-game-outcome-win-once-campaign-is-won
  (let ((game (make-queens-game :level 25)))
    (setf (queens-game-status game) :won)
    (is (eq :win (edm-engine:game-outcome game)))))

(test queens-game-score-method-matches-accumulated-score
  (let ((game (make-queens-game)))
    (setf (queens-game-score game) 250)
    (is (= 250 (edm-engine:game-score game)))))

;;; Cursor navigation (keyboard-driven, arrow keys move, Enter toggles)

(test cursor-starts-at-origin
  (let ((game (make-queens-game)))
    (is (= 0 (queens-game-cursor-row game)))
    (is (= 0 (queens-game-cursor-col game)))))

(test move-cursor-moves-within-bounds
  (let ((game (make-queens-game)))
    (move-cursor game 1 0)
    (is (= 1 (queens-game-cursor-row game)))
    (move-cursor game 0 1)
    (is (= 1 (queens-game-cursor-col game)))))

(test move-cursor-clamps-at-board-edges
  (let ((game (make-queens-game))) ; level 1 is a 4x4 board
    (move-cursor game -1 0)
    (is (= 0 (queens-game-cursor-row game)) "can't go above row 0")
    (move-cursor game 0 -1)
    (is (= 0 (queens-game-cursor-col game)) "can't go left of col 0")
    (dotimes (i 10) (move-cursor game 1 1))
    (is (= 3 (queens-game-cursor-row game)) "can't go past the last row")
    (is (= 3 (queens-game-cursor-col game)) "can't go past the last column")))

(test toggle-queen-at-cursor-places-and-removes-at-the-cursor-position
  (let ((game (make-queens-game)))
    (move-cursor game 2 1)
    (toggle-queen-at-cursor game)
    (is (member (cons 2 1) (queens-game-placed game) :test #'equal))
    (toggle-queen-at-cursor game)
    (is (not (member (cons 2 1) (queens-game-placed game) :test #'equal)))))

(test cursor-resets-to-origin-on-level-advance
  (let* ((game (make-queens-game :level 1))
         (board (queens-game-board game)))
    (move-cursor game 3 3)
    (loop for row from 0
          for col in (queens-board-placement board)
          do (setf (queens-game-cursor-row game) row (queens-game-cursor-col game) col)
             (toggle-queen-at-cursor game))
    (is (= 2 (queens-game-level game)))
    (is (= 0 (queens-game-cursor-row game)))
    (is (= 0 (queens-game-cursor-col game)))))
