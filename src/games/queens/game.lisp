(in-package :edm-engine/games/queens)

(declaim (optimize (speed 3) (safety 3)))

(defstruct (queens-game (:constructor %make-queens-game))
  (level 1 :type fixnum)
  (score 0 :type fixnum)
  (board nil :type (or null queens-board))
  (placed nil :type list)
  (status :playing :type (member :playing :won)))

(declaim (ftype (function (&key (:level fixnum)) queens-game) make-queens-game))
(defun make-queens-game (&key (level 1))
  (%make-queens-game :level level
                      :board (generate-board (queens-board-size-for-level level)
                                              (queens-seed-for-level level))))

(declaim (ftype (function (fixnum) fixnum) queens-game-points-for-level))
(defun queens-game-points-for-level (level)
  "Scales with board size (harder levels are worth more), 100 points per
board-size unit."
  (* 100 (queens-board-size-for-level level)))

(defun toggle-queen (game row col)
  "Places a queen at (ROW . COL) if empty, removes it if occupied. No-op
once GAME is :WON."
  (when (eq (queens-game-status game) :playing)
    (let ((cell (cons row col)))
      (if (member cell (queens-game-placed game) :test #'equal)
          (setf (queens-game-placed game) (remove cell (queens-game-placed game) :test #'equal))
          (push cell (queens-game-placed game)))
      (maybe-advance game)))
  game)

(declaim (ftype (function (queens-game) boolean) queens-solved-p))
(defun queens-solved-p (game)
  "T if GAME's current PLACED queens are a fully valid solution: one per
row, one per column, one per region, no two in row-adjacent-and-column-
adjacent cells."
  (let* ((board (queens-game-board game))
         (size (queens-board-size board))
         (placed (queens-game-placed game)))
    (and (= (length placed) size)
         (= size (length (remove-duplicates placed :key #'car)))  ; one per row
         (= size (length (remove-duplicates placed :key #'cdr)))  ; one per column
         (= size (length (remove-duplicates placed :key (lambda (c) (region-at board (car c) (cdr c))))))
         (loop for (r1 . c1) in placed
               always (loop for (r2 . c2) in placed
                            always (or (equal (cons r1 c1) (cons r2 c2))
                                       (> (max (abs (- r1 r2)) (abs (- c1 c2))) 1)))))))

(defun maybe-advance (game)
  "Checks whether GAME's current placement solves the level; if so,
banks that level's score and either wins the whole campaign (level 25
solved) or moves to a fresh board for the next level."
  (when (queens-solved-p game)
    (incf (queens-game-score game) (queens-game-points-for-level (queens-game-level game)))
    (if (>= (queens-game-level game) +queens-level-count+)
        (setf (queens-game-status game) :won)
        (progn
          (incf (queens-game-level game))
          (setf (queens-game-board game)
                (generate-board (queens-board-size-for-level (queens-game-level game))
                                 (queens-seed-for-level (queens-game-level game))))
          (setf (queens-game-placed game) nil)))))

(defmethod edm-engine:game-outcome ((game queens-game))
  (if (eq (queens-game-status game) :won) :win nil))

(defmethod edm-engine:game-score ((game queens-game))
  (queens-game-score game))
