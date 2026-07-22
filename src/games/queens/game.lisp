(in-package :edm-engine/games/queens)

(declaim (optimize (speed 3) (safety 3)))

(defstruct (queens-game (:constructor %make-queens-game))
  (level 1 :type fixnum)
  (score 0 :type fixnum)
  (board nil :type (or null queens-board))
  (placed nil :type list)   ; queens
  (marked nil :type list)   ; player X-marks — elimination notes, no rule significance
  (status :playing :type (member :playing :won))
  (cursor-row 0 :type fixnum)
  (cursor-col 0 :type fixnum))

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

;; #9's piece 2 — real save/restore, not the deceptive fake success
;; #9's own fix (ARCADE-POPUP-ITEMS omitting SAVE STATE) was papering
;; over. The board itself doesn't need serializing — MAKE-QUEENS-GAME
;; already regenerates it deterministically from LEVEL+a level-derived
;; seed; only the player's actual progress does.
;; #58's DEFSAVE-DATA retrofit — was a hand-written GAME-SAVE-DATA
;; method identical in shape to the other three games' own methods,
;; now declared as data via the macro composing this exact field list.
(edm-engine:defsave-data queens-game
  :level :score :placed :marked :status :cursor-row :cursor-col)

(defun queens-restore-game (data)
  "Reconstructs a QUEENS-GAME from a GAME-SAVE-DATA plist — the paired
half of that method, registered as this table's GAME-ENTRY RESTORE-FN.
MAKE-QUEENS-GAME's own constructor regenerates the board from LEVEL
alone (deterministic seed), then the player's real progress is
restored on top of that fresh board."
  (destructuring-bind (&key level score placed marked status cursor-row cursor-col &allow-other-keys) data
    (let ((game (make-queens-game :level level)))
      (setf (queens-game-score game) score
            (queens-game-placed game) placed
            (queens-game-marked game) marked
            (queens-game-status game) status
            (queens-game-cursor-row game) cursor-row
            (queens-game-cursor-col game) cursor-col)
      game)))

(declaim (ftype (function (queens-game fixnum fixnum) (member :empty :marked :queen)) cell-state))
(defun cell-state (game row col)
  (let ((cell (cons row col)))
    (cond ((member cell (queens-game-placed game) :test #'equal) :queen)
          ((member cell (queens-game-marked game) :test #'equal) :marked)
          (t :empty))))

(defun cycle-cell (game row col)
  "The real LinkedIn-Queens interaction: EMPTY -> MARKED (an 'X', a
non-committal elimination note with no rule significance) -> QUEEN ->
EMPTY. Not a plain two-state toggle — a mark lets a player rule out a
cell without committing to a queen there, exactly the 'miss-placed X'
state that needs its own test coverage, not just queen placement."
  (when (eq (queens-game-status game) :playing)
    (let ((cell (cons row col)))
      (ecase (cell-state game row col)
        (:empty (push cell (queens-game-marked game)))
        (:marked (setf (queens-game-marked game) (remove cell (queens-game-marked game) :test #'equal))
                 (push cell (queens-game-placed game)))
        (:queen (setf (queens-game-placed game) (remove cell (queens-game-placed game) :test #'equal))))
      (maybe-advance game)))
  game)

(defun cycle-cell-at-cursor (game)
  (cycle-cell game (queens-game-cursor-row game) (queens-game-cursor-col game)))

(declaim (ftype (function (fixnum fixnum) fixnum) clamp-to-board))
(defun clamp-to-board (value size)
  (max 0 (min (1- size) value)))

(defun move-cursor (game d-row d-col)
  "Moves GAME's cursor by (D-ROW, D-COL), clamped to the current board's
bounds — clamped, not wrapped, unlike ARCADE's menu-index cyclers
(CYCLE-INDEX): running off the edge of a game board should stop, not
wrap to the opposite side."
  (let ((size (queens-board-size (queens-game-board game))))
    (setf (queens-game-cursor-row game)
          (clamp-to-board (+ (queens-game-cursor-row game) d-row) size))
    (setf (queens-game-cursor-col game)
          (clamp-to-board (+ (queens-game-cursor-col game) d-col) size)))
  game)

(declaim (ftype (function (queens-game) list) queens-conflicts))
(defun queens-conflicts (game)
  "The 'miss-placed queen' feedback: every currently PLACED queen that
shares a row, column, region, or is king-move-adjacent with at least
one other placed queen. Works at any point during play, not just on a
full board — a genuine mid-game error state, not only a final-solution
check."
  (let ((board (queens-game-board game))
        (placed (queens-game-placed game)))
    (remove-if-not
     (lambda (cell)
       (destructuring-bind (r . c) cell
         (some (lambda (other)
                 (and (not (equal cell other))
                      (destructuring-bind (r2 . c2) other
                        (or (= r r2) (= c c2)
                            (= (region-at board r c) (region-at board r2 c2))
                            (<= (max (abs (- r r2)) (abs (- c c2))) 1)))))
               placed)))
     placed)))

(declaim (ftype (function (queens-game) boolean) queens-solved-p))
(defun queens-solved-p (game)
  "T if GAME's current PLACED queens are a fully valid solution: exactly
one per row/column/region, board-size many placed, and zero conflicts
among them — defined in terms of QUEENS-CONFLICTS rather than a second,
separately-maintained rule check."
  (and (= (length (queens-game-placed game)) (queens-board-size (queens-game-board game)))
       (null (queens-conflicts game))))

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
          (setf (queens-game-placed game) nil)
          (setf (queens-game-marked game) nil)
          (setf (queens-game-cursor-row game) 0)
          (setf (queens-game-cursor-col game) 0)))))

(defmethod edm-engine:game-outcome ((game queens-game))
  (if (eq (queens-game-status game) :won) :win nil))

(defmethod edm-engine:game-score ((game queens-game))
  (queens-game-score game))
