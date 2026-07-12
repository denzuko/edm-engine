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
only saturation/value differ."
  (multiple-value-bind (h-dim) (apply #'rgb->hsv (theme-color :dim))
    (multiple-value-bind (h-accent) (apply #'rgb->hsv (theme-color :accent))
      (is (< (abs (- h-dim h-accent)) 0.02)))))

(test theme-color-dim-is-darker-than-panel-is-darker-than-accent
  (flet ((brightness (c) (reduce #'max c)))
    (is (< (brightness (theme-color :dim)) (brightness (theme-color :panel))))
    (is (< (brightness (theme-color :panel)) (brightness (theme-color :accent))))))
