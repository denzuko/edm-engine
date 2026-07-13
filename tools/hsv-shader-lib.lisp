;;;; tools/hsv-shader-lib.lisp
;;;;
;;;; Shared c-mera HSV->RGB S-expression generator. This is the actual
;;;; reusable infrastructure investment: any future shader pack that
;;;; needs GPU-side hue-driven coloring (this engine's other tables,
;;;; isogame's rotoscoped renderer, whatever comes next) calls
;;;; HSV-COLOR-FORMS instead of re-deriving the hexagonal-cone
;;;; construction — the whole point of building it once, generally,
;;;; instead of hand-rolling color math per shader.
;;;;
;;;; Parameterized over variable/expression names rather than hardcoded
;;;; symbols, so callers can pass either plain uniform references
;;;; (chrome.fs's `value`/`saturation`) or computed expressions (a cell
;;;; shader whose value depends on `cursor`/`time`, not just a uniform).

(defparameter *hsv-sector-roles*
  '((:full :rising :min)
    (:falling :full :min)
    (:min :full :rising)
    (:min :falling :full)
    (:rising :min :full)
    (:full :min :falling))
  "Row I gives the (r g b) component role for hue-sector I. Each role
maps to one of the three chroma formulas via HSV-ROLE-EXPR — this table
IS the hexagonal-cone construction; nothing else needs to encode it.")

(defun hsv-role-expr (role value-expr saturation-expr f-var)
  (ecase role
    (:full value-expr)
    (:min `(* ,value-expr (- 1.0 ,saturation-expr)))
    (:rising `(* ,value-expr (- 1.0 (* ,saturation-expr (- 1.0 ,f-var)))))
    (:falling `(* ,value-expr (- 1.0 (* ,saturation-expr ,f-var))))))

(defun hsv-sector-branch (sector-index color-var value-expr saturation-expr h6-var f-var)
  (destructuring-bind (r g b) (nth sector-index *hsv-sector-roles*)
    `(progn
       (set ,f-var (- ,h6-var ,(float sector-index 1.0)))
       (set ,color-var (vec3 ,(hsv-role-expr r value-expr saturation-expr f-var)
                              ,(hsv-role-expr g value-expr saturation-expr f-var)
                              ,(hsv-role-expr b value-expr saturation-expr f-var))))))

(defun build-hsv-if-chain (color-var value-expr saturation-expr h6-var f-var &optional (sector 0))
  (if (= sector 5)
      (hsv-sector-branch 5 color-var value-expr saturation-expr h6-var f-var)
      `(if (< ,h6-var ,(float (1+ sector) 1.0))
           ,(hsv-sector-branch sector color-var value-expr saturation-expr h6-var f-var)
           ,(build-hsv-if-chain color-var value-expr saturation-expr h6-var f-var (1+ sector)))))

(defun hsv-color-forms (hue-expr color-var value-expr saturation-expr h6-var f-var)
  "Returns the c-mera forms that set H6-VAR from HUE-EXPR and then
COLOR-VAR to HSV(HUE-EXPR, SATURATION-EXPR, VALUE-EXPR). Caller must
have already DECL'd COLOR-VAR (vec3), H6-VAR (float), and F-VAR
(float) — this only emits the SET forms, not the declarations, since
callers may want other locals declared alongside them."
  `((set ,h6-var (* ,hue-expr 6.0))
    ,(build-hsv-if-chain color-var value-expr saturation-expr h6-var f-var)))
