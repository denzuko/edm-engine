(in-package :edm-engine)


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

(defun chrome-fragment-shader-path ()
  (namestring (asdf:system-relative-pathname :edm-engine "src/shaders/chrome.fs")))

(defun chrome-vertex-shader-path ()
  "PASSTHROUGH.VS is shared — chrome.fs.lisp never had its own paired
.vs; the vertex-shader half is identical to what tile.vs.lisp does,
so it's one shared file, not a same-named chrome.vs that never
actually got generated. (LOAD-SHADER silently falls back to raylib's
own default vertex shader when this path doesn't resolve, which is
functionally close enough to go unnoticed visually — but silently
wrong is still wrong.)"
  (namestring (asdf:system-relative-pathname :edm-engine "src/shaders/passthrough.vs")))

(defun ensure-chrome-shader ()
  (unless *chrome-shader*
    (setf *chrome-shader*
          (raylib:load-shader (chrome-vertex-shader-path) (chrome-fragment-shader-path)))
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

;;; Glyph font: raylib's DEFAULT font's coverage of card-suit
;;; (♠♥♦♣) and chess (♛) codepoints is unreliable — confirmed by a
;;; player actually watching a recording, not caught by pixel-bbox
;;; heuristics on a screenshot. Any table needing these (or future
;;; Unicode symbols) should load a REAL font with EXPLICIT codepoint
;;; coverage instead of gambling on the default font's glyph table.
;;; DejaVu Sans is bundled as a project asset (assets/fonts/) rather
;;; than referenced by a system path, so it's actually present wherever
;;; this engine ships, not just in a dev sandbox that happens to have it.

(defparameter +glyph-codepoints+ "♠♥♦♣♛"
  "Extra Unicode symbols this engine's tables need, beyond ASCII —
add to this string (not a separate font-load call) when a table needs
another glyph; it's one shared font, not one per table.")

(defvar *glyph-font* nil)
(defvar *glyph-font-size* 32)

(defun glyph-font-path ()
  (namestring (asdf:system-relative-pathname :edm-engine "assets/fonts/DejaVuSans.ttf")))

(defun ensure-glyph-font ()
  (unless *glyph-font*
    (let* ((codepoints (append (loop for c from 32 to 126 collect c)
                                (map 'list #'char-code +glyph-codepoints+)))
           (n (length codepoints)))
      (cffi:with-foreign-object (arr :int n)
        (loop for i from 0 for cp in codepoints do (setf (cffi:mem-aref arr :int i) cp))
        (setf *glyph-font* (raylib:load-font-ex (glyph-font-path) *glyph-font-size* arr n)))))
  *glyph-font*)

(declaim (ftype (function (string fixnum fixnum fixnum t &optional single-float) null) draw-glyph-text))
(defun draw-glyph-text (text x y font-size color &optional (spacing 1.0))
  "DRAW-TEXT equivalent that goes through the loaded glyph font instead
of raylib's default one — use this for any text that might contain a
card suit, the crown glyph, or future non-ASCII symbols; plain
RAYLIB:DRAW-TEXT is fine for ASCII-only UI text."
  (raylib:draw-text-ex (ensure-glyph-font) text (3d-vectors:vec2 (float x 1.0) (float y 1.0))
                        (float font-size 1.0) spacing color)
  nil)

(declaim (ftype (function (string fixnum) fixnum) glyph-text-width))
(defun glyph-text-width (text font-size)
  (round (3d-vectors:vx (raylib:measure-text-ex (ensure-glyph-font) text (float font-size 1.0) 1.0))))
