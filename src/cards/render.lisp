(in-package :edm-engine/cards)

(declaim (optimize (speed 3) (safety 3)))

;;; Real card shapes — a panel background + border + glyph, not just
;;; floating text on black. Generic across any card game: the shared
;;; monochromatic theme palette applied to an actual card silhouette,
;;; not a per-game reimplementation of the same rectangle+text drawing.

(defparameter +card-width+ 46.0)
(defparameter +card-height+ 62.0)
(defparameter +card-roundness+ 0.2)

(defun card-color (card)
  (if (member (cdr card) '(:hearts :diamonds))
      (edm-engine:rgb-color edm-engine:+color-red+)
      (edm-engine:rgb-color (edm-engine:theme-color :info))))

(defun card-rect (x y)
  (raylib:make-rectangle :x (float x 1.0) :y (float y 1.0) :width +card-width+ :height +card-height+))

(defun draw-card-back (x y &optional highlight-p)
  "A face-down card — panel fill, accent-tinted back pattern, no glyph."
  (let ((rect (card-rect x y)))
    (raylib:draw-rectangle-rounded rect +card-roundness+ 6 (edm-engine:rgb-color (edm-engine:theme-color :panel)))
    (raylib:draw-rectangle-rounded-lines rect +card-roundness+ 6 (if highlight-p 2.5 1.5)
                                          (edm-engine:rgb-color (edm-engine:theme-color (if highlight-p :accent :muted))))
    ;; a simple inset diamond as the "back pattern" — distinguishes a
    ;; back from a blank panel without needing a texture asset
    (raylib:draw-rectangle-rounded
     (raylib:make-rectangle :x (float (+ x 10) 1.0) :y (float (+ y 14) 1.0)
                             :width (- +card-width+ 20) :height (- +card-height+ 28))
     0.3 4 (edm-engine:rgb-color (edm-engine:theme-color :accent) 40))))

(defun draw-card-face (x y card &key (alpha 1.0) highlight-p selected-p)
  "A face-up card — panel fill, suit-colored glyph, ALPHA fades the
whole card (border+glyph together) for an illegal-to-play card rather
than swapping to a flat unrelated gray."
  (let* ((rect (card-rect x y))
         (fill (if selected-p (edm-engine:rgb-color (edm-engine:theme-color :accent) 60)
                   (edm-engine:rgb-color (edm-engine:theme-color :panel))))
         (border (raylib:fade (edm-engine:rgb-color (edm-engine:theme-color (if highlight-p :accent :muted))) alpha)))
    (raylib:draw-rectangle-rounded rect +card-roundness+ 6 fill)
    (raylib:draw-rectangle-rounded-lines rect +card-roundness+ 6 (if highlight-p 2.5 1.5) border)
    (edm-engine:draw-glyph-text (card-string card) (round (+ x 6)) (round (+ y 6)) 20
                                 (raylib:fade (card-color card) alpha))))
