(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

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

(defun draw-arena (arena)
  "Draws every live entity in ARENA as a filled circle at its position.
No logic here; ARENA state is produced entirely by ADVANCE-TICK."
  (raylib:with-drawing
    (raylib:clear-background :black)
    (dolist (h (arena-live-handles arena))
      (multiple-value-bind (x y) (arena-position arena h)
        (raylib:draw-circle (round x) (round y) 4.0 :green)))))
