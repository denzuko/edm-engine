(in-package :edm-engine/games/queens)

(declaim (optimize (speed 3) (safety 3)))

(defparameter +cell-size+ 60.0)
(defparameter +cell-gap+ 4.0)

(defun region-color (region-id size)
  "Reuses the engine's existing HSV->RGB/RGB-COLOR (src/palette.lisp,
already proven throughout the chrome/menu system) for region coloring —
evenly-spaced hues around the wheel, one per region — rather than
writing a second, GPU-shader copy of the same HSV math. A dedicated
Queens shader pack (selection glow, error flash, promotion effect) is
real follow-up work once this is actually playable, not a blocker to
shipping a working board."
  (edm-engine:rgb-color
   (edm-engine:hsv->rgb (/ (float region-id 1.0) size) 0.55 0.85)))

(defun queens-grid-origin (window-width window-height size)
  (let ((total (+ (* size +cell-size+) (* (1- size) +cell-gap+))))
    (values (/ (- window-width total) 2.0) (/ (- window-height total) 2.0))))

(defun draw-queens-board (game window-width window-height)
  (let* ((board (queens-game-board game))
         (size (queens-board-size board)))
    (multiple-value-bind (ox oy) (queens-grid-origin window-width window-height size)
      (dotimes (row size)
        (dotimes (col size)
          (let ((x (+ ox (* col (+ +cell-size+ +cell-gap+))))
                (y (+ oy (* row (+ +cell-size+ +cell-gap+)))))
            (raylib:draw-rectangle (round x) (round y) (round +cell-size+) (round +cell-size+)
                                    (region-color (region-at board row col) size))
            (when (member (cons row col) (queens-game-placed game) :test #'equal)
              (let* ((label "Q") (font-size 28)
                     (tw (raylib:measure-text label font-size)))
                (raylib:draw-text label (round (+ x (/ (- +cell-size+ tw) 2.0)))
                                   (round (+ y (/ (- +cell-size+ font-size) 2.0)))
                                   font-size :black)))
            (when (and (= row (queens-game-cursor-row game)) (= col (queens-game-cursor-col game)))
              (raylib:draw-rectangle-lines-ex
               (raylib:make-rectangle :x x :y y :width +cell-size+ :height +cell-size+)
               3.0 :white)))))
      (raylib:draw-text
       (format nil "Level ~D/~D   Score ~D" (queens-game-level game) +queens-level-count+
               (queens-game-score game))
       (round ox) (round (- oy 36)) 22 :white))))

(defmethod edm-engine:game-title ((game queens-game))
  "Queens")

(defmethod edm-engine:game-update ((game queens-game))
  (let ((before-row (queens-game-cursor-row game))
        (before-col (queens-game-cursor-col game))
        (before-level (queens-game-level game)))
    (when (raylib:is-key-pressed :key-up) (move-cursor game -1 0))
    (when (raylib:is-key-pressed :key-down) (move-cursor game 1 0))
    (when (raylib:is-key-pressed :key-left) (move-cursor game 0 -1))
    (when (raylib:is-key-pressed :key-right) (move-cursor game 0 1))
    (when (or (/= before-row (queens-game-cursor-row game)) (/= before-col (queens-game-cursor-col game)))
      (edm-engine/audio:play-tone :sine 500.0 0.03))
    (when (raylib:is-key-pressed :key-enter)
      (let ((placed-before (length (queens-game-placed game))))
        (toggle-queen-at-cursor game)
        (cond
          ((> (queens-game-level game) before-level)
           (edm-engine/audio:play-tone :sine 1000.0 0.3))
          ((> (length (queens-game-placed game)) placed-before)
           (edm-engine/audio:play-tone :square 700.0 0.05))
          (t (edm-engine/audio:play-tone :square 350.0 0.05)))))))

(defmethod edm-engine:game-render ((game queens-game) window-width window-height)
  (draw-queens-board game window-width window-height))

;; No :RESTORE-FN yet — Queens doesn't support save/load resume in this
;; first playable pass. An honest scope cut, not an oversight: the
;; slot system's contract (GAME-ENTRY-RESTORE-FN nil = "this table
;; doesn't support save/load") already handles it cleanly.
(edm-engine:register-game "Queens" (lambda () (make-queens-game)))
