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

(test theme-color-accent-matches-established-brand-color
  "The chrome shader's :accent role must reproduce +color-brand-green+
(now the CDE teal from unifiedspec.org, not literally green — the
constant name is legacy) exactly, not approximate it."
  (is (rgb-close-p (theme-color :accent) +color-brand-green+)))

(test theme-color-background-and-panel-share-the-warm-cream-hue
  "Dim (background) and panel are both Solarized's warm cream tones —
they should read as close hues, unlike the accent below."
  (multiple-value-bind (h-dim) (apply #'rgb->hsv (theme-color :dim))
    (multiple-value-bind (h-panel) (apply #'rgb->hsv (theme-color :panel))
      (is (< (abs (- h-dim h-panel)) 0.02)))))

(test theme-color-accent-is-a-genuinely-different-hue-from-the-background
  "This is the actual unifiedspec.org design: a warm cream background
paired with a cool CDE teal accent — not a monochromatic single-hue
theme. An earlier version of this palette was monochromatic; that was
the wrong direction (a terminal/BBS aesthetic), corrected in favor of
the real design system's own tokens."
  (multiple-value-bind (h-dim) (apply #'rgb->hsv (theme-color :dim))
    (multiple-value-bind (h-accent) (apply #'rgb->hsv (theme-color :accent))
      (is (> (abs (- h-dim h-accent)) 0.1)))))

(test theme-color-dim-and-panel-are-the-brightest-roles
  "Light-theme background: :dim (page) and :panel (cards) are bright
cream tones; :accent (teal) and :info (dark navy, for text/suits on
the light background) are meaningfully darker — the inverse brightness
ordering from a dark terminal theme, by design."
  (flet ((brightness (c) (reduce #'max c)))
    (is (> (brightness (theme-color :dim)) (brightness (theme-color :accent))))
    (is (> (brightness (theme-color :panel)) (brightness (theme-color :info))))))
