(in-package :edm-engine/games/wordle)

;; #59's audio piece — was six direct, inline PLAY-TONE calls, now
;; declared as data.
(edm-engine/audio:defaudio-cues :wordle
  (:letter-typed :square 800.0 0.05)
  (:letter-deleted :square 400.0 0.05)
  (:won :sine 1200.0 0.4)
  (:lost :sine 150.0 0.5)
  (:guess-submitted :sine 600.0 0.08)
  (:rejected :square 200.0 0.15))

(defparameter +cols+ 5)
(defparameter +rows+ 6)
(defparameter +tile-size+ 62.0)
(defparameter +tile-gap+ 8.0)

(defvar *tile-shader* nil)
(defvar *tile-state-loc* nil)
(defvar *tile-outcome-loc* nil)
(defvar *tile-time-loc* nil)

;; #24's fix — embedded at compile time, zero runtime file access.
(defparameter +tile-vertex-shader-source+
  (edm-engine/asset-embed:embedFileString "src/shaders/wordle/tile.vs" :system :edm-engine/games/wordle))
(defparameter +tile-fragment-shader-source+
  (edm-engine/asset-embed:embedFileString "src/shaders/wordle/tile.fs" :system :edm-engine/games/wordle))

(defun ensure-tile-shader ()
  "Lazily loads the tile shader pair."
  (unless *tile-shader*
    (setf *tile-shader* (raylib:load-shader-from-memory +tile-vertex-shader-source+ +tile-fragment-shader-source+))
    (setf *tile-state-loc* (raylib:get-shader-location *tile-shader* "state"))
    (setf *tile-outcome-loc* (raylib:get-shader-location *tile-shader* "outcome"))
    (setf *tile-time-loc* (raylib:get-shader-location *tile-shader* "time"))))

(declaim (ftype (function ((member nil :win :lose :tie)) (integer 0 3)) outcome-code))
(defun outcome-code (outcome)
  (ecase outcome ((nil) 0) (:win 1) (:lose 2) (:tie 3)))

(declaim (ftype (function ((member :empty :gray :yellow :green)) (integer 0 3)) state-code))
(defun state-code (state)
  (ecase state (:empty 0) (:gray 1) (:yellow 2) (:green 3)))

;; #36's DEFLAYOUT retrofit — was a bare CENTERED-GRID-POSITIONS call;
;; now declared as data via DEFLAYOUT itself, matching Queens' own
;; retrofit. +TILE-GAP+'s own value (8.0) genuinely IS +SPACE-2+ (8)
;; — checked directly, not assumed — used explicitly here.
(edm-engine:deflayout wordle-cell-position (row col window-width window-height rows cols)
  (:grid :rows rows :cols cols :item-w (round +tile-size+) :item-h (round +tile-size+)
         :gap-x edm-engine:+space-2+ :gap-y edm-engine:+space-2+
         :container-w window-width :container-h window-height
         :row-index row :col-index col))

(defun grid-origin (window-width window-height rows cols)
  "Top-left of a ROWS x COLS tile grid, centered in a WINDOW-WIDTH x
WINDOW-HEIGHT window."
  (multiple-value-bind (x y) (wordle-cell-position 0 0 window-width window-height rows cols)
    (values (float x 1.0) (float y 1.0))))

(defun draw-tile (x y state letter &optional (highlight 0.0) (outcome nil) (elapsed 0.0))
  "Draws one tile. Color comes entirely from the fragment shader via the
STATE uniform — the tile-state-to-color mapping lives in GLSL, not here.
HIGHLIGHT (0.0-1.0) draws a fading white outline, used for the
just-typed pulse animation. OUTCOME/ELAPSED drive the field-wide
win/lose/tie pulse — same shader, same mechanism as tile-state color.

#36's retrofit: the letter-centering formula was the third of the
three found duplicates (alongside Queens' mark label and queen glyph),
now composes CENTER-WITHIN."
  (ensure-tile-shader)
  (raylib:begin-shader-mode *tile-shader*)
  (edm-engine:set-shader-int *tile-shader* *tile-state-loc* (state-code state))
  (edm-engine:set-shader-int *tile-shader* *tile-outcome-loc* (outcome-code outcome))
  (edm-engine:set-shader-float *tile-shader* *tile-time-loc* elapsed)
  (raylib:draw-rectangle (round x) (round y) (round +tile-size+) (round +tile-size+) :white)
  (raylib:end-shader-mode)
  (when (plusp highlight)
    (raylib:draw-rectangle-lines-ex
     (raylib:make-rectangle :x (float x) :y (float y)
                             :width +tile-size+ :height +tile-size+)
     3.0 (raylib:fade :white highlight)))
  (when letter
    (let* ((s (string letter))
           (font-size 32)
           (tw (raylib:measure-text s font-size)))
      (multiple-value-bind (tx ty) (edm-engine:center-within (round x) (round y) (round +tile-size+) (round +tile-size+) tw font-size)
        (raylib:draw-text s tx ty font-size :white)))))

(defun draw-grid (window-width window-height rows-data
                   &key pulse-row pulse-col (pulse-fraction 0.0) outcome (elapsed 0.0))
  "ROWS-DATA is a list of rows; each row is a list of (LETTER . STATE)
cells, or NIL for an unfilled tile. STATE is one of
:EMPTY/:GRAY/:YELLOW/:GREEN. The grid is centered in the window.
PULSE-ROW/PULSE-COL/PULSE-FRACTION highlight one tile — the just-typed
letter's pop animation. OUTCOME/ELAPSED drive the field-wide win/lose/tie
pulse across every tile."
  (multiple-value-bind (ox oy)
      (grid-origin window-width window-height (length rows-data) +cols+)
    (loop for row in rows-data
          for row-i from 0
          do (loop for cell in row
                   for col-i from 0
                   do (draw-tile (+ ox (* col-i (+ +tile-size+ +tile-gap+)))
                                  (+ oy (* row-i (+ +tile-size+ +tile-gap+)))
                                  (if cell (cdr cell) :empty)
                                  (if cell (car cell) nil)
                                  (if (and (eql row-i pulse-row) (eql col-i pulse-col))
                                      pulse-fraction
                                      0.0)
                                  outcome
                                  elapsed)))))

(defmethod edm-engine:game-title ((game wordle-game))
  "Wordle")

(defvar *theme-sound* nil)

(defun ensure-theme-playing ()
  "#22: non-blocking — see Hearts' identical comment. The measured 44ms
RENDER-PATTERN hitch this was originally flagged against (this table's
own audio glitch) is what this retrofit actually fixes, not just
Hearts'."
  (unless *theme-sound*
    (setf *theme-sound*
          (edm-engine/audio:ensure-theme-sound-async
           (wordle-theme-pattern) +wordle-theme-row-duration+
           edm-engine:*engine-bus* :wordle-theme :amplitude 0.3)))
  (when (and *theme-sound* (not (raylib:is-sound-playing *theme-sound*)))
    (raylib:play-sound *theme-sound*)))

(defmethod edm-engine:game-update ((game wordle-game))
  "Reads keyboard input and drives GAME's incremental-typing state
machine. The typing logic itself (PUSH-LETTER/POP-LETTER/TRY-SUBMIT) is
pure and FiveAM-tested; only these raylib reads and the generated-tone
triggers are untested I/O."
  (ensure-theme-playing)
  (loop for code = (raylib:get-char-pressed)
        while (plusp code)
        do (let ((before (fill-pointer (wordle-game-input game))))
             (push-letter game (code-char code))
             (when (> (fill-pointer (wordle-game-input game)) before)
               (edm-engine:bus-push edm-engine:*engine-bus* :audio (list :game :wordle :cue :letter-typed)))))
  (when (raylib:is-key-pressed :key-backspace)
    (when (plusp (fill-pointer (wordle-game-input game)))
      (edm-engine:bus-push edm-engine:*engine-bus* :audio (list :game :wordle :cue :letter-deleted)))
    (pop-letter game))
  (when (raylib:is-key-pressed :key-enter)
    (case (try-submit game)
      (:submitted
       (ecase (wordle-game-status game)
         (:won (edm-engine:bus-push edm-engine:*engine-bus* :audio (list :game :wordle :cue :won)))
         (:lost (edm-engine:bus-push edm-engine:*engine-bus* :audio (list :game :wordle :cue :lost)))
         (:playing (edm-engine:bus-push edm-engine:*engine-bus* :audio (list :game :wordle :cue :guess-submitted)))))
      (:rejected (edm-engine:bus-push edm-engine:*engine-bus* :audio (list :game :wordle :cue :rejected)))))
  (tick-pulse game))

(defmethod edm-engine:game-render ((game wordle-game) window-width window-height)
  (let ((pulse-row (length (wordle-game-history game)))
        (pulse-col (1- (fill-pointer (wordle-game-input game)))))
    (draw-grid window-width window-height (rows-for-render game)
               :pulse-row (when (and (plusp (wordle-game-pulse game)) (>= pulse-col 0)) pulse-row)
               :pulse-col (when (>= pulse-col 0) pulse-col)
               :pulse-fraction (/ (wordle-game-pulse game) (float +pulse-max+))
               :outcome (edm-engine:game-outcome game)
               :elapsed (raylib:get-time))))

(defmethod edm-engine:game-stop-audio ((game wordle-game))
  (declare (ignore game))
  (when *theme-sound* (raylib:stop-sound *theme-sound*)))

(edm-engine:register-game
 "Wordle"
 (lambda () (make-wordle-game (nth (random (length *corpus*)) *corpus*)))
 :restore-fn #'wordle-restore-game)
