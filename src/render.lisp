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

;; #24's fix: embedded at compile time, not resolved via a runtime
;; file path — the actual reason PASSTHROUGH.VS is shared (one
;; embedded copy, not a same-named chrome.vs that never got
;; generated) is unchanged from before; only how the source reaches
;; RAYLIB changes, from a file path LOAD-SHADER reads at runtime to a
;; string LOAD-SHADER-FROM-MEMORY already has in hand.
(defparameter +chrome-fragment-shader-source+
  (edm-engine/asset-embed:embedFileString "src/shaders/chrome.fs"))
(defparameter +chrome-vertex-shader-source+
  (edm-engine/asset-embed:embedFileString "src/shaders/passthrough.vs"))

(defun ensure-chrome-shader ()
  (unless *chrome-shader*
    (setf *chrome-shader*
          (raylib:load-shader-from-memory +chrome-vertex-shader-source+ +chrome-fragment-shader-source+))
    (setf *chrome-hue-loc* (raylib:get-shader-location *chrome-shader* "hue"))
    (setf *chrome-saturation-loc* (raylib:get-shader-location *chrome-shader* "saturation"))
    (setf *chrome-value-loc* (raylib:get-shader-location *chrome-shader* "value"))
    (setf *chrome-alpha-loc* (raylib:get-shader-location *chrome-shader* "alpha"))))

(declaim (ftype (function (fixnum fixnum fixnum fixnum (member :dim :panel :muted :accent :info)
                           &optional single-float)
                          null)
                draw-chrome-rect))
(defun draw-chrome-rect (x y width height role &optional (alpha 1.0))
  "GPU mode (default): a solid rectangle whose color is computed on the
GPU from ROLE's (hue saturation value) — genuinely shader-driven, not
a pre-computed RGB literal. Retheming the whole engine is changing
+THEME-HUE+, not editing draw calls.
CPU mode: no shader, no fill, no color — a flat monotone outline, the
minimum needed to see where a panel/region is at a fraction of the
GPU cost."
  (ecase *render-mode*
    (:gpu
     (ensure-chrome-shader)
     (multiple-value-bind (h s v) (theme-hsv role)
       (raylib:begin-shader-mode *chrome-shader*)
       (set-shader-float *chrome-shader* *chrome-hue-loc* h)
       (set-shader-float *chrome-shader* *chrome-saturation-loc* s)
       (set-shader-float *chrome-shader* *chrome-value-loc* v)
       (set-shader-float *chrome-shader* *chrome-alpha-loc* alpha)
       (raylib:draw-rectangle x y width height :white)
       (raylib:end-shader-mode)))
    (:cpu
     (raylib:draw-rectangle-lines-ex
      (raylib:make-rectangle :x (float x 1.0) :y (float y 1.0) :width (float width 1.0) :height (float height 1.0))
      1.0 (if (eq *theme-direction* :dark) :white :black))))
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

(defparameter +glyph-codepoints+ "♠♥♦♣♛♞♟"
  "Extra Unicode symbols this engine's tables need, beyond ASCII —
add to this string (not a separate font-load call) when a table needs
another glyph; it's one shared font, not one per table.")

(defvar *glyph-font* nil)
(defvar *glyph-font-size* 32)

;; #24's fix — embedded at compile time, zero runtime file access.
(defparameter +glyph-font-bytes+
  (edm-engine/asset-embed:embedFileBytes "assets/fonts/DejaVuSans.ttf"))

(defun ensure-glyph-font ()
  (unless *glyph-font*
    (let* ((codepoints (append (loop for c from 32 to 126 collect c)
                                (map 'list #'char-code +glyph-codepoints+)))
           (n (length codepoints)))
      (cffi:with-foreign-object (arr :int n)
        (loop for i from 0 for cp in codepoints do (setf (cffi:mem-aref arr :int i) cp))
        (cffi:with-pointer-to-vector-data (data-ptr +glyph-font-bytes+)
          (setf *glyph-font*
                (raylib:load-font-from-memory ".ttf" data-ptr (length +glyph-font-bytes+)
                                               *glyph-font-size* arr n))))))
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

(declaim (ftype (function (string fixnum fixnum fixnum fixnum t &key (:line-height fixnum)) fixnum)
                draw-wrapped-text))
(defun draw-wrapped-text (text x y max-width font-size color &key (line-height (round (* font-size 1.3))))
  "Wraps TEXT to fit MAX-WIDTH using real measured glyph widths (not a
character-count guess) and draws each line via DRAW-GLYPH-TEXT — the
fix for the difficulty screen's description text running straight off
one card's edge into the next. Returns the total height drawn, so a
caller can lay out whatever comes after it."
  (let ((lines (wrap-text-lines text (lambda (s) (glyph-text-width s font-size)) max-width)))
    (loop for line in lines
          for i from 0
          do (draw-glyph-text line x (+ y (* i line-height)) font-size color))
    (* (length lines) line-height)))

;;; unifiedspec.org's two-register typography: Titillium Web for UI/
;;; display (headings, labels, buttons) and Inconsolata for the
;;; technical register (code, paths, tags) — see denzuko/unifiedspec's
;;; tokens.json, typography.font-family. Bundled as project assets
;;; (OFL-licensed, license text alongside) rather than a system-font
;;; reference, same reasoning as the glyph font.

(defvar *ui-font* nil)
(defvar *mono-font* nil)
(defparameter +ui-font-size+ 48
  "Loaded at a large base size; DRAW-UI-TEXT draws at whatever size is
requested, scaled down from this — normal raylib font usage.")
(defparameter +mono-font-size+ 32)

;; #24's fix — embedded at compile time, zero runtime file access.
(defparameter +ui-font-bytes+
  (edm-engine/asset-embed:embedFileBytes "assets/fonts/TitilliumWeb-Bold.ttf"))
(defparameter +mono-font-bytes+
  (edm-engine/asset-embed:embedFileBytes "assets/fonts/Inconsolata-Regular.ttf"))

(defun ensure-ui-font ()
  (unless *ui-font*
    (cffi:with-pointer-to-vector-data (data-ptr +ui-font-bytes+)
      (setf *ui-font*
            (raylib:load-font-from-memory ".ttf" data-ptr (length +ui-font-bytes+)
                                           +ui-font-size+ (cffi:null-pointer) 0))))
  *ui-font*)

(defun ensure-mono-font ()
  (unless *mono-font*
    (cffi:with-pointer-to-vector-data (data-ptr +mono-font-bytes+)
      (setf *mono-font*
            (raylib:load-font-from-memory ".ttf" data-ptr (length +mono-font-bytes+)
                                           +mono-font-size+ (cffi:null-pointer) 0))))
  *mono-font*)

(declaim (ftype (function (string fixnum fixnum fixnum t &optional single-float) null) draw-ui-text))
(defun draw-ui-text (text x y font-size color &optional (spacing 1.0))
  (raylib:draw-text-ex (ensure-ui-font) text (3d-vectors:vec2 (float x 1.0) (float y 1.0))
                        (float font-size 1.0) spacing color)
  nil)

(declaim (ftype (function (string fixnum) fixnum) ui-text-width))
(defun ui-text-width (text font-size)
  (round (3d-vectors:vx (raylib:measure-text-ex (ensure-ui-font) text (float font-size 1.0) 1.0))))

;;; unifiedspec's spacing scale (4px base unit) and border-radius scale
;;; — named so layout code reads as intent, not magic numbers.

(defparameter +space-1+ 4) (defparameter +space-2+ 8) (defparameter +space-3+ 12)
(defparameter +space-4+ 16) (defparameter +space-5+ 24) (defparameter +space-6+ 32)
(defparameter +space-7+ 48) (defparameter +space-8+ 64)
(defparameter +radius-sm+ 0.03) (defparameter +radius-md+ 0.06) (defparameter +radius-lg+ 0.1)
