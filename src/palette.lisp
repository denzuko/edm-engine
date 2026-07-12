(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

;;; Chrome palette: the established DPS/denzuko terminal identity,
;;; slimmed down for game UI (menus, backgrounds, overlays). Functional
;;; game-state colors (Wordle's tile states, and any future table's
;;; equivalent) intentionally do NOT use this palette — see
;;; +okabe-ito-*+ below.

(defparameter +color-dim+ '(0.039 0.039 0.039))        ; #0a0a0a — window background
(defparameter +color-panel+ '(0.051 0.067 0.090))      ; #0d1117 — overlay/tile background
(defparameter +color-brand-green+ '(0.224 1.0 0.078))  ; #39ff14 — menu selection, brand accent
(defparameter +color-brand-green2+ '(0.0 0.784 0.325)) ; #00c853 — secondary accent
(defparameter +color-amber+ '(1.0 0.671 0.0))          ; #ffab00
(defparameter +color-red+ '(1.0 0.090 0.267))          ; #ff1744

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
