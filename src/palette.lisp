(in-package :edm-engine)


;;; Chrome palette: unifiedspec.org's actual tokens (Solarized +
;;; Okabe-Ito + Solaris/CDE lineages — see denzuko/unifiedspec), not an
;;; invented DPS-terminal near-black scheme. The design system's own
;;; default is the LIGHT Solarized palette (tokens.json:
;;; "background.base: light: base3 (#fdf6e3), dark: base03" — light is
;;; listed first, the reference case), which reads as a warm, inviting
;;; tabletop surface — the classic-Hoyle-games direction — not a
;;; terminal/BBS-door aesthetic. Functional game-state colors (Wordle's
;;; tile states) intentionally do NOT use this palette — see
;;; +okabe-ito-*+ below.

(defparameter +color-dim+ '(0.992 0.965 0.890))        ; #fdf6e3 (Solarized base3) — window background
(defparameter +color-panel+ '(0.933 0.910 0.835))       ; #eee8d5 (Solarized base2) — panel/card surface
(defparameter +color-brand-green+ '(0.0 0.502 0.502))   ; #008080 (Solaris/CDE teal) — accent, selection
(defparameter +color-brand-green2+ '(0.0 0.333 0.333))  ; #005555 (CDE teal-dk) — accent border
(defparameter +color-amber+ '(0.816 0.251 0.0))         ; #d04000 (Solaris/CDE orange) — warn/highlight
(defparameter +color-red+ '(0.863 0.196 0.184))         ; #dc322f (Solarized red)

;;; Okabe & Ito (2008) colorblind-safe qualitative palette, used for
;;; functional state indicators where the color itself carries game
;;; meaning — Wordle's green/yellow correct-vs-present distinction is
;;; exactly the failure case this palette exists to fix.

(defparameter +okabe-ito-orange+ '(0.902 0.624 0.0))      ; #E69F00
(defparameter +okabe-ito-bluish-green+ '(0.0 0.620 0.451)) ; #009E73
(defparameter +okabe-ito-sky-blue+ '(0.337 0.706 0.914))   ; #56B4E9

(declaim (ftype (function (list) list) rgb-scaled))
(defun rgb-scaled (triple scale)
  "TRIPLE's components each multiplied by SCALE — used to derive a
muted/neutral tone from a palette color without introducing an
unrelated gray."
  (mapcar (lambda (c) (* c scale)) triple))

;;; Theme roles map to unifiedspec's actual semantic tokens — this is
;;; NOT a monochromatic single-hue system (an earlier version of this
;;; file was; the real Solarized palette deliberately pairs a warm
;;; background with a cool teal accent, which a single rotating hue
;;; can't represent). THEME-HSV still returns (hue saturation value)
;;; per role because the chrome shader is GPU-side HSV math, but each
;;; role now has its own fixed hue matching the source hex value, not
;;; a shared +THEME-HUE+.

(declaim (ftype (function (single-float single-float single-float) list) hsv->rgb))
(defun hsv->rgb (h s v)
  "H, S, V each in [0,1]. Returns (r g b), each in [0,1]."
  (if (zerop s)
      (list v v v)
      (let* ((h6 (* (mod h 1.0) 6.0))
             (i (floor h6))
             (f (- h6 i))
             (p (* v (- 1 s)))
             (q (* v (- 1 (* s f))))
             (tt (* v (- 1 (* s (- 1 f))))))
        (ecase (mod i 6)
          (0 (list v tt p))
          (1 (list q v p))
          (2 (list p v tt))
          (3 (list p q v))
          (4 (list tt p v))
          (5 (list v p q))))))

(declaim (ftype (function (single-float single-float single-float) (values single-float single-float single-float)) rgb->hsv))
(defun rgb->hsv (r g b)
  "Inverse of HSV->RGB. Returns (values h s v), each in [0,1]."
  (let* ((maxc (max r g b))
         (minc (min r g b))
         (delta (- maxc minc))
         (v maxc)
         (s (if (zerop maxc) 0.0 (/ delta maxc)))
         (h (cond
              ((zerop delta) 0.0)
              ((= maxc r) (mod (/ (- g b) delta) 6.0))
              ((= maxc g) (+ (/ (- b r) delta) 2.0))
              (t (+ (/ (- r g) delta) 4.0)))))
    (values (/ h 6.0) s v)))

(defparameter +theme-hue+
  (nth-value 0 (apply #'rgb->hsv +color-brand-green+))
  "The accent's own hue (CDE teal) — kept for any caller that still
wants 'the theme's hue' as a single value, but individual roles below
no longer all share it; see THEME-HSV's docstring.")

(declaim (ftype (function ((member :dim :panel :muted :accent :info))
                          (values single-float single-float single-float)) theme-hsv))
(defun theme-hsv (role)
  "Raw (hue saturation value) for ROLE, each role's own hue from its
unifiedspec source color (Solarized base3/base2 for backgrounds,
CDE teal for accent, Solarized base03 for high-contrast text/info) —
not a shared rotating hue. Both THEME-COLOR (CPU-side RGB, for text)
and the chrome shader (GPU-side, for backgrounds) derive from this."
  (ecase role
    (:dim (values 0.1218 0.1028 0.9922))    ; #fdf6e3 Solarized base3
    (:panel (values 0.1267 0.1050 0.9333))  ; #eee8d5 Solarized base2
    (:muted (values 0.5444 0.2290 0.5137))  ; #657b83 Solarized base00
    (:info (values 0.5340 1.0 0.2118))      ; #002b36 Solarized base03
    (:accent (values 0.5 1.0 0.502))))      ; #008080 CDE teal

(declaim (ftype (function ((member :dim :panel :muted :accent :info)) list) theme-color))
(defun theme-color (role)
  (multiple-value-bind (h s v) (theme-hsv role)
    (hsv->rgb h s v)))
