(in-package :edm-engine/games/wordle)

(declaim (optimize (speed 3) (safety 3)))

(defparameter +cols+ 5)
(defparameter +rows+ 6)
(defparameter +tile-size+ 62.0)
(defparameter +tile-gap+ 8.0)

(defvar *tile-shader* nil)
(defvar *tile-state-loc* nil)
(defvar *tile-outcome-loc* nil)
(defvar *tile-time-loc* nil)

(defun tile-shader-path (extension)
  (namestring (asdf:system-relative-pathname
               :edm-engine/games/wordle
               (format nil "src/games/wordle/shaders/tile.~A" extension))))

(defun ensure-tile-shader ()
  "Lazily loads the tile shader pair. cl-raylib's LOAD-SHADER takes plain
:string CFFI args, so NIL (raylib's own \"use default vertex shader\"
convention) doesn't translate to NULL here — the vertex shader is a
standard raylib passthrough, loaded explicitly instead."
  (unless *tile-shader*
    (setf *tile-shader* (raylib:load-shader (tile-shader-path "vs") (tile-shader-path "fs")))
    (setf *tile-state-loc* (raylib:get-shader-location *tile-shader* "state"))
    (setf *tile-outcome-loc* (raylib:get-shader-location *tile-shader* "outcome"))
    (setf *tile-time-loc* (raylib:get-shader-location *tile-shader* "time"))))

(declaim (ftype (function ((member nil :win :lose :tie)) (integer 0 3)) outcome-code))
(defun outcome-code (outcome)
  (ecase outcome ((nil) 0) (:win 1) (:lose 2) (:tie 3)))

(declaim (ftype (function ((member :empty :gray :yellow :green)) (integer 0 3)) state-code))
(defun state-code (state)
  (ecase state (:empty 0) (:gray 1) (:yellow 2) (:green 3)))

(defun grid-origin (window-width window-height rows cols)
  "Top-left of a ROWS x COLS tile grid, centered in a WINDOW-WIDTH x
WINDOW-HEIGHT window."
  (let ((total-w (+ (* cols +tile-size+) (* (1- cols) +tile-gap+)))
        (total-h (+ (* rows +tile-size+) (* (1- rows) +tile-gap+))))
    (values (/ (- window-width total-w) 2.0)
            (/ (- window-height total-h) 2.0))))

(defun draw-tile (x y state letter &optional (highlight 0.0) (outcome nil) (elapsed 0.0))
  "Draws one tile. Color comes entirely from the fragment shader via the
STATE uniform — the tile-state-to-color mapping lives in GLSL, not here.
HIGHLIGHT (0.0-1.0) draws a fading white outline, used for the
just-typed pulse animation. OUTCOME/ELAPSED drive the field-wide
win/lose/tie pulse — same shader, same mechanism as tile-state color."
  (ensure-tile-shader)
  (cffi:with-foreign-object (state-ptr :int)
    (setf (cffi:mem-ref state-ptr :int) (state-code state))
    (raylib:begin-shader-mode *tile-shader*)
    (raylib:set-shader-value *tile-shader* *tile-state-loc* state-ptr :shader-uniform-int)
    (cffi:with-foreign-object (outcome-ptr :int)
      (setf (cffi:mem-ref outcome-ptr :int) (outcome-code outcome))
      (raylib:set-shader-value *tile-shader* *tile-outcome-loc* outcome-ptr :shader-uniform-int))
    (cffi:with-foreign-object (time-ptr :float)
      (setf (cffi:mem-ref time-ptr :float) (float elapsed 1.0))
      (raylib:set-shader-value *tile-shader* *tile-time-loc* time-ptr :shader-uniform-float))
    (raylib:draw-rectangle (round x) (round y) (round +tile-size+) (round +tile-size+) :white)
    (raylib:end-shader-mode))
  (when (plusp highlight)
    (raylib:draw-rectangle-lines-ex
     (raylib:make-rectangle :x (float x) :y (float y)
                             :width +tile-size+ :height +tile-size+)
     3.0 (raylib:fade :white highlight)))
  (when letter
    (let* ((s (string letter))
           (font-size 32)
           (tw (raylib:measure-text s font-size)))
      (raylib:draw-text s
                         (round (+ x (/ (- +tile-size+ tw) 2.0)))
                         (round (+ y (/ (- +tile-size+ font-size) 2.0)))
                         font-size :white))))

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

(defmethod edm-engine:game-update ((game wordle-game))
  "Reads keyboard input and drives GAME's incremental-typing state
machine. The typing logic itself (PUSH-LETTER/POP-LETTER/TRY-SUBMIT) is
pure and FiveAM-tested; only these raylib reads and the generated-tone
triggers are untested I/O."
  (loop for code = (raylib:get-char-pressed)
        while (plusp code)
        do (let ((before (fill-pointer (wordle-game-input game))))
             (push-letter game (code-char code))
             (when (> (fill-pointer (wordle-game-input game)) before)
               (edm-engine/audio:play-tone :square 800.0 0.05))))
  (when (raylib:is-key-pressed :key-backspace)
    (when (plusp (fill-pointer (wordle-game-input game)))
      (edm-engine/audio:play-tone :square 400.0 0.05))
    (pop-letter game))
  (when (raylib:is-key-pressed :key-enter)
    (let ((history-count (length (wordle-game-history game))))
      (try-submit game)
      (when (> (length (wordle-game-history game)) history-count)
        (ecase (wordle-game-status game)
          (:won (edm-engine/audio:play-tone :sine 1200.0 0.4))
          (:lost (edm-engine/audio:play-tone :sine 150.0 0.5))
          (:playing (edm-engine/audio:play-tone :sine 600.0 0.08))))))
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

(edm-engine:register-game
 "Wordle"
 (lambda () (make-wordle-game (nth (random (length *corpus*)) *corpus*))))
