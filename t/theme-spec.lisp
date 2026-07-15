(in-package :edm-engine/tests)
(in-suite :edm-engine)

(defun rgb-close-p (a b &optional (tolerance 0.01))
  (< (loop for x in a for y in b sum (abs (- x y))) tolerance))

(test hsv->rgb-full-saturation-value-matches-pure-hue-colors
  (is (rgb-close-p '(1.0 0.0 0.0) (hsv->rgb 0.0 1.0 1.0)))         ; red
  (is (rgb-close-p '(0.0 1.0 0.0) (hsv->rgb (/ 1.0 3.0) 1.0 1.0))) ; green
  (is (rgb-close-p '(0.0 0.0 1.0) (hsv->rgb (/ 2.0 3.0) 1.0 1.0)))) ; blue

(test hsv->rgb-zero-saturation-is-grayscale
  (is (rgb-close-p '(0.5 0.5 0.5) (hsv->rgb 0.3 0.0 0.5))))

(test hsv->rgb-zero-value-is-black-regardless-of-hue
  (is (rgb-close-p '(0.0 0.0 0.0) (hsv->rgb 0.7 1.0 0.0))))

(test rgb->hsv->rgb-round-trips
  (dolist (rgb '((1.0 0.0 0.0) (0.224 1.0 0.078) (0.5 0.5 0.5) (0.902 0.624 0.0)))
    (multiple-value-bind (h s v) (apply #'rgb->hsv rgb)
      (is (rgb-close-p rgb (hsv->rgb h s v))))))

(test theme-color-accent-matches-established-brand-green
  "The monochromatic theme's hue is derived from +color-brand-green+
itself, so :accent must reproduce it exactly, not approximate it."
  (is (rgb-close-p (theme-color :accent) +color-brand-green+)))

(test theme-color-roles-share-one-hue-at-different-intensities
  "The whole point of a monochromatic theme: every role's hue matches,
only saturation/value differ. (A prior revision replaced this with
per-role hardcoded hues from unifiedspec.org's Solarized/CDE tokens —
an over-correction, reverted; single-hue-driven is the actual design.)"
  (multiple-value-bind (h-dim) (apply #'rgb->hsv (theme-color :dim))
    (multiple-value-bind (h-accent) (apply #'rgb->hsv (theme-color :accent))
      (is (< (abs (- h-dim h-accent)) 0.02)))))

(test theme-color-dim-is-the-brightest-role-accent-is-vivid-not-pale
  "Light background (unifiedspec's actual default, not a dark
terminal): :DIM (page) is the brightest role; :ACCENT (chrome/CTAs) is
a vivid, saturated teal, not a pale tint — the inverse brightness
ordering from a dark-terminal theme, by design."
  (flet ((brightness (c) (reduce #'max c)))
    (is (> (brightness (theme-color :dim)) (brightness (theme-color :panel))))
    (is (> (brightness (theme-color :dim)) (brightness (theme-color :accent))))))

;;; Runtime theme-direction switching (GH #6) — *THEME-DIRECTION*
;;; defaults to :LIGHT (unifiedspec's actual default) and is mutable at
;;; runtime, not a load-time constant; THEME-HSV/THEME-COLOR dispatch
;;; on it without changing their own call signature, so no caller
;;; anywhere else in the codebase needed touching.

(test theme-direction-defaults-to-light
  (is (eq :light *theme-direction*)))

(test theme-direction-dark-inverts-the-brightness-ordering
  (let ((*theme-direction* :dark))
    (flet ((brightness (c) (reduce #'max c)))
      (is (< (brightness (theme-color :dim)) (brightness (theme-color :accent)))))))

(test theme-direction-light-and-dark-still-share-one-hue
  (dolist (direction '(:light :dark))
    (let ((*theme-direction* direction))
      (multiple-value-bind (h-dim) (apply #'rgb->hsv (theme-color :dim))
        (multiple-value-bind (h-accent) (apply #'rgb->hsv (theme-color :accent))
          (is (< (abs (- h-dim h-accent)) 0.02)))))))
