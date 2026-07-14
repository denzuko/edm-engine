(in-package :edm-engine)


(defparameter +engine-name+ "PARENCADE")
(defparameter +main-menu-items+ '("Tables" "Engine Options" "Save / Load"))

(declaim (ftype (function (fixnum fixnum fixnum) fixnum) cycle-index))
(defun cycle-index (current delta bound)
  "CURRENT shifted by DELTA (typically +1/-1), wrapped into [0, BOUND) —
this exact MOD arithmetic was duplicated identically across all six
ARCADE-SELECT-NEXT-*/ARCADE-SELECT-PREVIOUS-* functions, differing only
in which struct slot and which bound."
  (mod (+ current delta) bound))

(defstruct (arcade-state (:constructor make-arcade-state))
  (mode :title :type (member :title :main-menu :tables :playing :options :save-load :difficulty))
  (main-menu-index 0 :type fixnum)
  (table-index 0 :type fixnum)
  (current-game nil)
  (current-table-title nil)
  (ruleset-handle nil)
  (total-score 0 :type fixnum)
  (volume 1.0 :type single-float)
  (popup-open nil :type boolean)
  (popup-index 0 :type fixnum)
  (save-slot-index 0 :type fixnum)
  (difficulty-index 0 :type fixnum)
  (pending-entry nil))

;;; Top-level main menu: Tables / Engine Options / Save-Load

(defun arcade-select-next-main-menu (state)
  (setf (arcade-state-main-menu-index state)
        (cycle-index (arcade-state-main-menu-index state) 1 (length +main-menu-items+))))

(defun arcade-select-previous-main-menu (state)
  (setf (arcade-state-main-menu-index state)
        (cycle-index (arcade-state-main-menu-index state) -1 (length +main-menu-items+))))

(defun arcade-drill-into-main-menu-selection (state)
  (setf (arcade-state-mode state)
        (ecase (arcade-state-main-menu-index state)
          (0 :tables)
          (1 :options)
          (2 :save-load))))

(defun arcade-back-to-main-menu (state)
  (setf (arcade-state-mode state) :main-menu))

(defun arcade-dismiss-title (state)
  (setf (arcade-state-mode state) :main-menu))

;;; Engine Options — real, minimal: master volume

(declaim (ftype (function (single-float) single-float) clamp-volume))
(defun clamp-volume (v) (max 0.0 (min 1.0 v)))

(defun arcade-increase-volume (state)
  (setf (arcade-state-volume state) (clamp-volume (+ (arcade-state-volume state) 0.1))))

(defun arcade-decrease-volume (state)
  (setf (arcade-state-volume state) (clamp-volume (- (arcade-state-volume state) 0.1))))

;;; Tables (game selection)

(defun arcade-select-next-table (state)
  (when *games*
    (setf (arcade-state-table-index state)
          (cycle-index (arcade-state-table-index state) 1 (length *games*)))))

(defun arcade-select-previous-table (state)
  (when *games*
    (setf (arcade-state-table-index state)
          (cycle-index (arcade-state-table-index state) -1 (length *games*)))))

(defun arcade-complete-launch (state entry)
  (let ((game (funcall (game-entry-constructor entry))))
    (setf (arcade-state-current-game state) game
          (arcade-state-current-table-title state) (game-entry-title entry)
          (arcade-state-ruleset-handle state) (ruleset-load game)
          (arcade-state-mode state) :playing
          (arcade-state-popup-open state) nil
          (arcade-state-popup-index state) 0)))

(defun arcade-launch-selected (state)
  (let ((entry (nth (arcade-state-table-index state) *games*)))
    (when entry
      (if (game-entry-ai-capable-p entry)
          (setf (arcade-state-pending-entry state) entry
                (arcade-state-difficulty-index state) 0
                (arcade-state-mode state) :difficulty)
          (arcade-complete-launch state entry)))))

;;; Difficulty selection — shown before launch for any AI-capable table

(defun arcade-select-next-difficulty (state)
  (setf (arcade-state-difficulty-index state)
        (cycle-index (arcade-state-difficulty-index state) 1 (length +ai-difficulty-tiers+))))

(defun arcade-select-previous-difficulty (state)
  (setf (arcade-state-difficulty-index state)
        (cycle-index (arcade-state-difficulty-index state) -1 (length +ai-difficulty-tiers+))))

(defun arcade-confirm-difficulty (state)
  "Binds *AI-DIFFICULTY* to the chosen tier for the duration of the
constructor call — any AI-capable game's MAKE-<GAME> reads it there if
its AI logic cares."
  (let ((entry (arcade-state-pending-entry state))
        (tier (nth (arcade-state-difficulty-index state) +ai-difficulty-tiers+)))
    (let ((*ai-difficulty* tier))
      (arcade-complete-launch state entry))
    (setf (arcade-state-pending-entry state) nil)))

;;; Playing: pause/outcome popup, scoring, save, restart, return to table select

(defun arcade-popup-items (game)
  "RESUME is only offered while GAME is still in progress — nothing to
resume once it's over."
  (if (game-outcome game)
      '("New Game" "Save State" "Return to Tables")
      '("Resume" "New Game" "Save State" "Return to Tables")))

(defun arcade-open-popup (state)
  (setf (arcade-state-popup-open state) t
        (arcade-state-popup-index state) 0))

(defun arcade-popup-next (state)
  (let ((n (length (arcade-popup-items (arcade-state-current-game state)))))
    (setf (arcade-state-popup-index state) (mod (1+ (arcade-state-popup-index state)) n))))

(defun arcade-popup-previous (state)
  (let ((n (length (arcade-popup-items (arcade-state-current-game state)))))
    (setf (arcade-state-popup-index state) (mod (1- (arcade-state-popup-index state)) n))))

(defun arcade-bank-score (state)
  "Adds the current game's score to the running total. Safe to call
unconditionally — GAME-SCORE's default is 0, and a game that hasn't
concluded yet also scores 0, so this never double-counts or counts
early; it only ever adds something on a genuine win."
  (when (arcade-state-current-game state)
    (incf (arcade-state-total-score state) (game-score (arcade-state-current-game state)))))

(defun arcade-restart-current (state)
  "Relaunches the table STATE was already playing — looked up by the
title recorded at launch, not by calling GAME-TITLE on the (possibly
finished, possibly a test double) current instance."
  (arcade-bank-score state)
  (let ((entry (find (arcade-state-current-table-title state) *games*
                      :key #'game-entry-title :test #'string=)))
    (when entry
      (ruleset-unload (arcade-state-current-game state) (arcade-state-ruleset-handle state))
      (let ((game (funcall (game-entry-constructor entry))))
        (setf (arcade-state-current-game state) game
              (arcade-state-ruleset-handle state) (ruleset-load game)
              (arcade-state-mode state) :playing
              (arcade-state-popup-open state) nil
              (arcade-state-popup-index state) 0)))))

(defun arcade-return-to-table-select (state)
  (arcade-bank-score state)
  (ruleset-unload (arcade-state-current-game state) (arcade-state-ruleset-handle state))
  (setf (arcade-state-current-game state) nil
        (arcade-state-current-table-title state) nil
        (arcade-state-ruleset-handle state) nil
        (arcade-state-mode state) :tables
        (arcade-state-popup-open state) nil
        (arcade-state-popup-index state) 0))

(defun arcade-save-current (state)
  "Saves the in-progress table into STATE's currently browsed slot
(ARCADE-STATE-SAVE-SLOT-INDEX — pick a different one first via the
Save/Load screen's up/down, same navigation as everywhere else), then
returns to table select. Returns the slot index."
  (when (arcade-state-current-game state)
    (save-game-to-slot (arcade-state-save-slot-index state)
                        (arcade-state-current-table-title state)
                        (arcade-state-current-game state)
                        (arcade-state-total-score state)))
  (arcade-return-to-table-select state)
  (arcade-state-save-slot-index state))

(defun arcade-popup-confirm (state)
  "Dispatches on the highlighted popup item's TEXT, not a raw index —
RESUME only exists in the in-progress variant of ARCADE-POPUP-ITEMS, so
indexing by position alone would pick the wrong action once the two
variants' lengths differ."
  (let* ((game (arcade-state-current-game state))
         (item (nth (arcade-state-popup-index state) (arcade-popup-items game))))
    (cond
      ((string= item "Resume") (setf (arcade-state-popup-open state) nil))
      ((string= item "New Game") (arcade-restart-current state))
      ((string= item "Save State") (arcade-save-current state))
      ((string= item "Return to Tables") (arcade-return-to-table-select state)))))

;;; Save/Load main-menu screen — browse up to *SAVE-SLOT-COUNT* slots

(defun arcade-select-next-save-slot (state)
  (setf (arcade-state-save-slot-index state)
        (cycle-index (arcade-state-save-slot-index state) 1 *save-slot-count*)))

(defun arcade-select-previous-save-slot (state)
  (setf (arcade-state-save-slot-index state)
        (cycle-index (arcade-state-save-slot-index state) -1 *save-slot-count*)))

(defun arcade-load-selected-save-slot (state)
  "Loads STATE's currently browsed slot and resumes play. Returns T on
success, NIL if the slot is empty, or the saved table no longer
supports RESTORE-FN (dropped that support, or was never registered — a
stale save from a build that no longer matches this one)."
  (multiple-value-bind (title score timestamp data)
      (load-game-from-slot (arcade-state-save-slot-index state))
    (declare (ignore timestamp))
    (when title
      (let ((entry (find title *games* :key #'game-entry-title :test #'string=)))
        (when (and entry (game-entry-restore-fn entry))
          (ruleset-unload (arcade-state-current-game state) (arcade-state-ruleset-handle state))
          (let ((game (funcall (game-entry-restore-fn entry) data)))
            (setf (arcade-state-current-game state) game
                  (arcade-state-current-table-title state) title
                  (arcade-state-total-score state) (or score 0)
                  (arcade-state-ruleset-handle state) (ruleset-load game)
                  (arcade-state-mode state) :playing
                  (arcade-state-popup-open state) nil
                  (arcade-state-popup-index state) 0)
            t))))))
