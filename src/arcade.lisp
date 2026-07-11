(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

(defparameter +engine-name+ "PARENCADE")
(defparameter +main-menu-items+ '("Tables" "Engine Options" "Save / Load"))

(defstruct (arcade-state (:constructor make-arcade-state))
  (mode :main-menu :type (member :main-menu :tables :playing :options :save-load))
  (main-menu-index 0 :type fixnum)
  (table-index 0 :type fixnum)
  (current-game nil)
  (current-table-title nil)
  (ruleset-handle nil))

;;; Top-level main menu: Tables / Engine Options / Save-Load

(defun arcade-select-next-main-menu (state)
  (setf (arcade-state-main-menu-index state)
        (mod (1+ (arcade-state-main-menu-index state)) (length +main-menu-items+))))

(defun arcade-select-previous-main-menu (state)
  (setf (arcade-state-main-menu-index state)
        (mod (1- (arcade-state-main-menu-index state)) (length +main-menu-items+))))

(defun arcade-drill-into-main-menu-selection (state)
  (setf (arcade-state-mode state)
        (ecase (arcade-state-main-menu-index state)
          (0 :tables)
          (1 :options)
          (2 :save-load))))

(defun arcade-back-to-main-menu (state)
  (setf (arcade-state-mode state) :main-menu))

;;; Tables (game selection)

(defun arcade-select-next-table (state)
  (when *games*
    (setf (arcade-state-table-index state)
          (mod (1+ (arcade-state-table-index state)) (length *games*)))))

(defun arcade-select-previous-table (state)
  (when *games*
    (setf (arcade-state-table-index state)
          (mod (1- (arcade-state-table-index state)) (length *games*)))))

(defun arcade-launch-selected (state)
  (let ((entry (nth (arcade-state-table-index state) *games*)))
    (when entry
      (let ((game (funcall (game-entry-constructor entry))))
        (setf (arcade-state-current-game state) game
              (arcade-state-current-table-title state) (game-entry-title entry)
              (arcade-state-ruleset-handle state) (ruleset-load game)
              (arcade-state-mode state) :playing)))))

;;; Playing: restart, return to table select

(defun arcade-restart-current (state)
  "Relaunches the table STATE was already playing — looked up by the
title recorded at launch, not by calling GAME-TITLE on the (possibly
finished, possibly a test double) current instance."
  (let ((entry (find (arcade-state-current-table-title state) *games*
                      :key #'game-entry-title :test #'string=)))
    (when entry
      (ruleset-unload (arcade-state-current-game state) (arcade-state-ruleset-handle state))
      (let ((game (funcall (game-entry-constructor entry))))
        (setf (arcade-state-current-game state) game
              (arcade-state-ruleset-handle state) (ruleset-load game)
              (arcade-state-mode state) :playing)))))

(defun arcade-return-to-table-select (state)
  (ruleset-unload (arcade-state-current-game state) (arcade-state-ruleset-handle state))
  (setf (arcade-state-current-game state) nil
        (arcade-state-current-table-title state) nil
        (arcade-state-ruleset-handle state) nil
        (arcade-state-mode state) :tables))
