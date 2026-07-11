(in-package :edm-engine/games/wordle)

(declaim (optimize (speed 3) (safety 3)))

(defparameter +cols+ 5)
(defparameter +rows+ 6)
(defparameter +tile-size+ 62.0)
(defparameter +tile-gap+ 8.0)

(defvar *tile-shader* nil)
(defvar *tile-state-loc* nil)

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
    (setf *tile-state-loc* (raylib:get-shader-location *tile-shader* "state"))))

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

(defun draw-tile (x y state letter)
  "Draws one tile. Color comes entirely from the fragment shader via the
STATE uniform — the tile-state-to-color mapping lives in GLSL, not here."
  (ensure-tile-shader)
  (cffi:with-foreign-object (state-ptr :int)
    (setf (cffi:mem-ref state-ptr :int) (state-code state))
    (raylib:begin-shader-mode *tile-shader*)
    (raylib:set-shader-value *tile-shader* *tile-state-loc* state-ptr :shader-uniform-int)
    (raylib:draw-rectangle (round x) (round y) (round +tile-size+) (round +tile-size+) :white)
    (raylib:end-shader-mode))
  (when letter
    (let* ((s (string letter))
           (font-size 32)
           (tw (raylib:measure-text s font-size)))
      (raylib:draw-text s
                         (round (+ x (/ (- +tile-size+ tw) 2.0)))
                         (round (+ y (/ (- +tile-size+ font-size) 2.0)))
                         font-size :white))))

(defun draw-grid (window-width window-height rows-data)
  "ROWS-DATA is a list of rows; each row is a list of (LETTER . STATE)
cells, or NIL for an unfilled tile. STATE is one of
:EMPTY/:GRAY/:YELLOW/:GREEN. The grid is centered in the window."
  (multiple-value-bind (ox oy)
      (grid-origin window-width window-height (length rows-data) +cols+)
    (loop for row in rows-data
          for row-i from 0
          do (loop for cell in row
                   for col-i from 0
                   do (draw-tile (+ ox (* col-i (+ +tile-size+ +tile-gap+)))
                                  (+ oy (* row-i (+ +tile-size+ +tile-gap+)))
                                  (if cell (cdr cell) :empty)
                                  (if cell (car cell) nil))))))
