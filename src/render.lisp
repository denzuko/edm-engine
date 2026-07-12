(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

(defun open-window (title width height)
  (raylib:init-window width height title)
  (raylib:set-target-fps 60)
  ;; raylib's default: ESC sets WINDOW-SHOULD-CLOSE regardless of any
  ;; is-key-pressed check elsewhere. The arcade uses ESC for its own
  ;; pause-menu/back-navigation — left at the default, every ESC press
  ;; would silently terminate the whole loop out from under it.
  (raylib:set-exit-key :key-null))

(defun close-window () (raylib:close-window))

(defun window-should-close-p () (raylib:window-should-close))

;;; Shared shader-uniform-setting ceremony. Every shader in this engine
;;; (tile.fs's state/outcome/time, chrome.fs's hue/saturation/value/alpha,
;;; and whatever a future table's own shader pack needs) sets scalar
;;; uniforms the same way: allocate a foreign scalar, write the value,
;;; hand it to SET-SHADER-VALUE. That ceremony was duplicated verbatim
;;; three times in draw-tile and four times in draw-chrome-rect before
;;; this; one definition now, reused everywhere.

(defun set-shader-int (shader location value)
  (cffi:with-foreign-object (ptr :int)
    (setf (cffi:mem-ref ptr :int) value)
    (raylib:set-shader-value shader location ptr :shader-uniform-int)))

(defun set-shader-float (shader location value)
  (cffi:with-foreign-object (ptr :float)
    (setf (cffi:mem-ref ptr :float) (float value 1.0))
    (raylib:set-shader-value shader location ptr :shader-uniform-float)))

(defun draw-arena (arena)
  "Draws every live entity in ARENA as a filled circle at its position.
No logic here; ARENA state is produced entirely by ADVANCE-TICK."
  (raylib:with-drawing
    (raylib:clear-background :black)
    (dolist (h (arena-live-handles arena))
      (multiple-value-bind (x y) (arena-position arena h)
        (raylib:draw-circle (round x) (round y) 4.0 :green)))))

;;; Chrome shader: genuine GPU-driven monochromatic theming. One shader,
;;; parameterized by hue/saturation/value/alpha uniforms derived from
;;; THEME-HSV — a theme swap is a new hue, not a new shader file.

(defvar *chrome-shader* nil)
(defvar *chrome-hue-loc* nil)
(defvar *chrome-saturation-loc* nil)
(defvar *chrome-value-loc* nil)
(defvar *chrome-alpha-loc* nil)

(defun chrome-shader-path (extension)
  (namestring (asdf:system-relative-pathname
               :edm-engine (format nil "src/shaders/chrome.~A" extension))))

(defun ensure-chrome-shader ()
  (unless *chrome-shader*
    (setf *chrome-shader*
          (raylib:load-shader (chrome-shader-path "vs") (chrome-shader-path "fs")))
    (setf *chrome-hue-loc* (raylib:get-shader-location *chrome-shader* "hue"))
    (setf *chrome-saturation-loc* (raylib:get-shader-location *chrome-shader* "saturation"))
    (setf *chrome-value-loc* (raylib:get-shader-location *chrome-shader* "value"))
    (setf *chrome-alpha-loc* (raylib:get-shader-location *chrome-shader* "alpha"))))

(declaim (ftype (function (fixnum fixnum fixnum fixnum (member :dim :panel :muted :accent :info)
                           &optional single-float)
                          null)
                draw-chrome-rect))
(defun draw-chrome-rect (x y width height role &optional (alpha 1.0))
  "Draws a solid rectangle whose color is computed on the GPU from
ROLE's (hue saturation value) — genuinely shader-driven, not a
pre-computed RGB literal. Retheming the whole engine is changing
+THEME-HUE+, not editing draw calls."
  (ensure-chrome-shader)
  (multiple-value-bind (h s v) (theme-hsv role)
    (raylib:begin-shader-mode *chrome-shader*)
    (set-shader-float *chrome-shader* *chrome-hue-loc* h)
    (set-shader-float *chrome-shader* *chrome-saturation-loc* s)
    (set-shader-float *chrome-shader* *chrome-value-loc* v)
    (set-shader-float *chrome-shader* *chrome-alpha-loc* alpha)
    (raylib:draw-rectangle x y width height :white)
    (raylib:end-shader-mode))
  nil)
