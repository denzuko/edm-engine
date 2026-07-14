(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

;;; Chrome palette: the DPS/denzuko terminal identity, driven by
;;; unifiedspec.org's Solaris/CDE lineage (teal, #008080 — see
;;; denzuko/unifiedspec's tokens.json, palette.solaris-cde.teal) rather
;;; than an invented neon green. Functional game-state colors (Wordle's
;;; tile states, and any future table's equivalent) intentionally do
;;; NOT use this palette — see +okabe-ito-*+ below.
;;;
;;; Two things this project got wrong at different times, both
;;; corrected now: (1) replacing the single-hue architecture with
;;; hardcoded per-role Solarized/CDE literals (commit d01aa3c) — an
;;; architectural regression, reverted; (2) reverting all the way back
;;; to an invented neon-green hue instead of unifiedspec's actual CDE
;;; teal — reverting the regression shouldn't have meant reverting the
;;; design direction too. The fix is both at once: ONE hue drives
;;; everything (THEME-HSV below), and that hue is unifiedspec's teal,
;;; not a made-up terminal green.

(defparameter +color-dim+ '(0.008 0.031 0.031))        ; near-black at the teal hue — window background
(defparameter +color-panel+ '(0.020 0.078 0.078))      ; overlay/tile background
(defparameter +color-brand-green+ '(0.0 0.502 0.502))  ; #008080 (Solaris/CDE teal) — menu selection, brand accent
(defparameter +color-brand-green2+ '(0.0 0.333 0.333)) ; #005555 (CDE teal-dk) — secondary accent
(defparameter +color-amber+ '(0.816 0.251 0.0))        ; #d04000 (Solaris/CDE orange, "Sun logo block")
(defparameter +color-red+ '(0.863 0.196 0.184))        ; #dc322f (Solarized red)

;;; Okabe & Ito (2008) colorblind-safe qualitative palette, used for
;;; functional state indicators where the color itself carries game
;;; meaning — Wordle's green/yellow correct-vs-present distinction is
;;; exactly the failure case this palette exists to fix; a brand-first
;;; neon green/amber pair is not reliably distinguishable under
;;; deuteranopia/protanopia the way orange/bluish-green is.

(defparameter +okabe-ito-orange+ '(0.902 0.624 0.0))      ; #E69F00
(defparameter +okabe-ito-bluish-green+ '(0.0 0.620 0.451)) ; #009E73
(defparameter +okabe-ito-sky-blue+ '(0.337 0.706 0.914))   ; #56B4E9

(declaim (ftype (function (list) list) rgb-scaled))
(defun rgb-scaled (triple scale)
  "TRIPLE's components each multiplied by SCALE — used to derive a
muted/neutral tone from a palette color without introducing an
unrelated gray."
  (mapcar (lambda (c) (* c scale)) triple))

;;; Monochromatic HSV theming for chrome (menus, backgrounds, panels).
;;; One hue defines a whole theme's identity; UI roles are expressed as
;;; different saturation/value at that same hue — genuinely how a
;;; green-on-black terminal reads, not an arbitrary design choice.
;;; Functional game-state colors (Wordle's tile states) deliberately
;;; do NOT go through this system — see tile.fs.lisp's docstring for why
;;; free hue-rotation is unsafe for colorblind-accessibility-load-bearing
;;; colors specifically.

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
  "Derived from +COLOR-BRAND-GREEN+ itself so :ACCENT reproduces the
established brand color exactly, not an approximation of it. The
single value that drives the whole chrome palette — change this one
number to re-theme the entire engine.")

(declaim (ftype (function ((member :dim :panel :muted :accent :info))
                          (values single-float single-float single-float)) theme-hsv))
(defun theme-hsv (role)
  "Raw (hue saturation value) for ROLE — the single source of truth
both THEME-COLOR (CPU-side RGB, for text) and the chrome shader
(GPU-side, for backgrounds) derive from. Every role shares
+THEME-HUE+; only saturation/value differ per role."
  (ecase role
    (:dim (values +theme-hue+ 0.15 0.04))
    (:panel (values +theme-hue+ 0.3 0.09))
    (:muted (values +theme-hue+ 0.15 0.4))
    (:info (values +theme-hue+ 0.1 0.92))
    (:accent (values +theme-hue+ 1.0 0.502))))     ; #008080 exactly

(declaim (ftype (function ((member :dim :panel :muted :accent :info)) list) theme-color))
(defun theme-color (role)
  (multiple-value-bind (h s v) (theme-hsv role)
    (hsv->rgb h s v)))
