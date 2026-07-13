(in-package :edm-engine/games/queens/tests)
(in-suite :edm-engine-queens)

(defun place-queen (game row col)
  "Test helper: drives the real two-step cycle (mark, then queen) rather
than reaching into internal slots — exercises the actual player-facing
interaction, not a shortcut around it."
  (cycle-cell game row col)
  (cycle-cell game row col))

(test make-queens-game-starts-at-level-1-with-a-generated-board
  (let ((game (make-queens-game)))
    (is (= 1 (queens-game-level game)))
    (is (= 4 (queens-board-size (queens-game-board game))))
    (is (eq :playing (queens-game-status game)))
    (is (= 0 (queens-game-score game)))))

;;; The real cell cycle: empty -> marked -> queen -> empty

(test cycle-cell-first-press-marks-not-places-a-queen
  "The exact 'miss-placed X' state — a single press is a note, not a
commitment."
  (let ((game (make-queens-game)))
    (cycle-cell game 0 0)
    (is (eq :marked (cell-state game 0 0)))
    (is (not (member (cons 0 0) (queens-game-placed game) :test #'equal)))))

(test cycle-cell-second-press-places-a-queen-and-clears-the-mark
  (let ((game (make-queens-game)))
    (cycle-cell game 0 0)
    (cycle-cell game 0 0)
    (is (eq :queen (cell-state game 0 0)))
    (is (not (member (cons 0 0) (queens-game-marked game) :test #'equal)))))

(test cycle-cell-third-press-clears-back-to-empty
  (let ((game (make-queens-game)))
    (cycle-cell game 0 0)
    (cycle-cell game 0 0)
    (cycle-cell game 0 0)
    (is (eq :empty (cell-state game 0 0)))))

(test cycle-cell-does-nothing-once-game-is-won
  (let ((game (make-queens-game :level 25)))
    (setf (queens-game-status game) :won)
    (cycle-cell game 0 0)
    (is (eq :empty (cell-state game 0 0)))))

(test marks-do-not-count-toward-solving-the-level
  "A fully-marked board (every cell an X, zero queens) must never solve —
marks have no rule significance."
  (let ((game (make-queens-game :level 1)))
    (dotimes (row 4)
      (dotimes (col 4)
        (cycle-cell game row col))) ; one press each: all MARKED, no queens
    (is (eq :playing (queens-game-status game)))
    (is (= 1 (queens-game-level game)))))

;;; Conflicts — the actual "fail"/"miss-placed queen" states, tested
;;; individually per rule, not just as a single lumped-together case

(test queens-conflicts-empty-for-an-empty-board
  (let ((game (make-queens-game)))
    (is (null (queens-conflicts game)))))

(test queens-conflicts-detects-same-row
  (let ((game (make-queens-game)))
    (place-queen game 0 0)
    (place-queen game 0 2)
    (let ((conflicts (queens-conflicts game)))
      (is (= 2 (length conflicts)))
      (is (member (cons 0 0) conflicts :test #'equal))
      (is (member (cons 0 2) conflicts :test #'equal)))))

(test queens-conflicts-detects-same-column
  (let ((game (make-queens-game)))
    (place-queen game 0 0)
    (place-queen game 3 0)
    (is (= 2 (length (queens-conflicts game))))))

(test queens-conflicts-detects-same-region
  (let* ((game (make-queens-game))
         (board (queens-game-board game))
         (r0 (region-at board 0 0)))
    ;; find a second cell sharing region R0 that isn't row/col-adjacent
    ;; to (0,0) so only the region rule is exercised
    (let ((other (loop for row below 4 append
                        (loop for col below 4
                              when (and (= r0 (region-at board row col))
                                        (not (and (= row 0) (= col 0)))
                                        (> (max (abs row) (abs col)) 1))
                                collect (cons row col)))))
      (when other
        (place-queen game 0 0)
        (place-queen game (car (first other)) (cdr (first other)))
        (is (> (length (queens-conflicts game)) 0))))))

(test queens-conflicts-detects-adjacency
  (let ((game (make-queens-game)))
    (place-queen game 0 0)
    (place-queen game 1 1) ; diagonally touching (0,0)
    (is (= 2 (length (queens-conflicts game))))))

(test queens-conflicts-non-conflicting-queens-report-clean
  (let* ((game (make-queens-game))
         (board (queens-game-board game))
         (solution (queens-board-placement board)))
    (place-queen game 0 (first solution))
    (is (null (queens-conflicts game)))))

(test an-invalid-full-placement-does-not-advance-the-level
  (let ((game (make-queens-game :level 1)))
    (place-queen game 0 0)
    (place-queen game 1 0) ; same column as (0,0) — a real conflict
    (place-queen game 2 1)
    (place-queen game 3 2)
    (is (not (null (queens-conflicts game))))
    (is (eq :playing (queens-game-status game)))
    (is (= 1 (queens-game-level game)))))

;;; Solving — the real win path, driven through the actual mark-then-
;;; queen cycle, not a shortcut

(test placing-the-generated-solution-advances-to-the-next-level
  (let* ((game (make-queens-game :level 1))
         (board (queens-game-board game)))
    (loop for row from 0
          for col in (queens-board-placement board)
          do (place-queen game row col))
    (is (= 2 (queens-game-level game)))
    (is (eq :playing (queens-game-status game)))
    (is (null (queens-game-placed game)) "next level starts with an empty board")
    (is (null (queens-game-marked game)) "marks are also cleared on advance")))

(test placing-the-solution-on-the-final-level-wins-the-whole-campaign
  (let* ((game (make-queens-game :level 25))
         (board (queens-game-board game)))
    (loop for row from 0
          for col in (queens-board-placement board)
          do (place-queen game row col))
    (is (eq :won (queens-game-status game)))))

(test score-accumulates-across-level-advances
  (let* ((game (make-queens-game :level 1))
         (board (queens-game-board game)))
    (is (= 0 (queens-game-score game)))
    (loop for row from 0
          for col in (queens-board-placement board)
          do (place-queen game row col))
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

;;; Cursor navigation (keyboard-driven, arrow keys move, Enter cycles)

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

(test cycle-cell-at-cursor-operates-on-the-cursor-position
  (let ((game (make-queens-game)))
    (move-cursor game 2 1)
    (cycle-cell-at-cursor game)
    (is (eq :marked (cell-state game 2 1)))
    (cycle-cell-at-cursor game)
    (is (eq :queen (cell-state game 2 1)))))

(test cursor-resets-to-origin-on-level-advance
  (let* ((game (make-queens-game :level 1))
         (board (queens-game-board game)))
    (move-cursor game 3 3)
    (loop for row from 0
          for col in (queens-board-placement board)
          do (setf (queens-game-cursor-row game) row (queens-game-cursor-col game) col)
             (place-queen game row col))
    (is (= 2 (queens-game-level game)))
    (is (= 0 (queens-game-cursor-row game)))
    (is (= 0 (queens-game-cursor-col game)))))
