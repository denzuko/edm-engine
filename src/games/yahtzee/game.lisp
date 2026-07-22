(in-package :edm-engine/games/yahtzee)

(defstruct (yahtzee-game (:constructor %make-yahtzee-game))
  (dice '(1 1 1 1 1) :type list)
  (held (list nil nil nil nil nil) :type list)
  (rolls-remaining 3 :type fixnum)
  (scores nil :type list)
  (turn 0 :type fixnum)
  (player-count 4 :type fixnum)
  (cursor 0 :type fixnum)
  (roll-seed 1 :type fixnum)
  (roll-animation nil)
  (status :playing :type (member :playing :won :lost))
  ;; #30's actual fix — same as HEARTS-GAME's own slot, same reasoning:
  ;; captured at construction time while *AI-DIFFICULTY* is still
  ;; correctly bound, not read later from the render layer.
  (ai-difficulty :novice :type (member :novice :standard :expert)))

(defun make-yahtzee-game (&key (seed 1) (player-count 4))
  (%make-yahtzee-game :player-count player-count
                       :scores (loop repeat player-count collect nil)
                       :roll-seed seed
                       :ai-difficulty edm-engine:*ai-difficulty*))

(defun roll-turn-dice (game)
  (when (plusp (yahtzee-game-rolls-remaining game))
    (incf (yahtzee-game-roll-seed game))
    (setf (yahtzee-game-dice game)
          (reroll-dice (yahtzee-game-dice game) (yahtzee-game-held game) (yahtzee-game-roll-seed game)))
    (decf (yahtzee-game-rolls-remaining game))))

(defun toggle-hold (game i)
  (setf (nth i (yahtzee-game-held game)) (not (nth i (yahtzee-game-held game)))))

;; #9's piece 2, completing — real save/restore. Same shape as Hearts:
;; dice/held/scores/turn are all live, in-progress state, not
;; regeneratable from ROLL-SEED alone once rolls/holds/scoring have
;; modified it.
;; #58's DEFSAVE-DATA retrofit — was a hand-written GAME-SAVE-DATA
;; method identical in shape to the other three games' own methods,
;; now declared as data via the macro composing this exact field list.
(edm-engine:defsave-data yahtzee-game
  :dice :held :rolls-remaining :scores :turn :player-count :cursor
  :roll-seed :status :ai-difficulty)

(defun yahtzee-restore-game (data)
  "Reconstructs a YAHTZEE-GAME from a GAME-SAVE-DATA plist — the paired
half of that method, registered as this table's GAME-ENTRY RESTORE-FN.
Uses %MAKE-YAHTZEE-GAME (the raw constructor) since the exact,
already-in-progress state is restored directly, not regenerated.
ROLL-ANIMATION resets to NIL — a transient in-progress animation, not
meaningful across a save/load boundary, same reasoning as Hearts'
TRICK-PAUSE-UNTIL."
  (destructuring-bind (&key dice held rolls-remaining scores turn player-count
                          cursor roll-seed status ai-difficulty &allow-other-keys)
      data
    (%make-yahtzee-game :dice dice :held held :rolls-remaining rolls-remaining
                         :scores scores :turn turn :player-count player-count
                         :cursor cursor :roll-seed roll-seed :roll-animation nil
                         :status status :ai-difficulty ai-difficulty)))

(defun available-categories (game player)
  (remove-if (lambda (cat) (getf (nth player (yahtzee-game-scores game)) cat)) +categories+))

(defun commit-score (game category)
  "Fills CATEGORY for the current player with their current dice roll,
then advances to the next player with a fresh set of rolls and held
dice cleared."
  (let ((player (yahtzee-game-turn game)))
    (setf (nth player (yahtzee-game-scores game))
          (append (nth player (yahtzee-game-scores game))
                  (list category (score-category category (yahtzee-game-dice game)))))
    (setf (yahtzee-game-turn game) (mod (1+ player) (yahtzee-game-player-count game))
          (yahtzee-game-rolls-remaining game) 3
          (yahtzee-game-held game) (list nil nil nil nil nil)
          (yahtzee-game-cursor game) 0)))

(defun turn-over-p (game)
  "True once the CURRENT player (about to act) has already filled
every category — i.e. their turn is done, not that the whole game is."
  (null (available-categories game (yahtzee-game-turn game))))

(defun game-over-p (game)
  (every (lambda (scores) (= (length +categories+) (/ (length scores) 2)))
         (yahtzee-game-scores game)))

(defun winner-index (game)
  (let ((totals (mapcar #'grand-total (yahtzee-game-scores game))))
    (position (reduce #'max totals) totals)))

(defmethod edm-engine:game-outcome ((game yahtzee-game))
  (case (yahtzee-game-status game)
    (:won :win)
    (:lost :lose)
    (t nil)))

(defmethod edm-engine:game-score ((game yahtzee-game))
  (grand-total (first (yahtzee-game-scores game))))

(defun advance-turn (game)
  "Skips over any player who has already filled every category — used
when player counts differ in how many categories are left, so turns
don't get offered to someone with nothing left to score."
  (loop while (and (not (game-over-p game))
                    (null (available-categories game (yahtzee-game-turn game))))
        do (setf (yahtzee-game-turn game) (mod (1+ (yahtzee-game-turn game)) (yahtzee-game-player-count game)))))

;;; Simple heuristic AI — reroll dice that aren't part of the
;;; best-looking pattern so far, score into whatever category the
;;; current dice score highest in among what's still available. Same
;;; scope discipline as Hearts: real turn selection under a UI
;;; think-delay, not a SCREAMER problem.

(defun ai-choose-holds (dice previous-held)
  (declare (ignore previous-held))
  (let* ((counts (mapcar (lambda (v) (cons v (count v dice))) (remove-duplicates dice)))
         (best-value (car (reduce (lambda (a b) (if (>= (cdr a) (cdr b)) a b)) counts))))
    (mapcar (lambda (d) (= d best-value)) dice)))

(defun ai-choose-category (dice available)
  (first (sort (copy-list available) #'> :key (lambda (cat) (score-category cat dice)))))
