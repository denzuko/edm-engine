(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

;;; Reusable tween/easing engine — the "floating card transitioning and
;;; easing into its placement" effect from the original per-table-
;;; effects discussion, built for real once a genuine second use case
;;; (Hearts' card movement) justified it, matching the same
;;; build-it-when-actually-needed discipline as Queens' cell shader.
;;; Pure math, no raylib dependency — the I/O layer just calls
;;; TWEEN-POSITION each frame and draws there instead of at a fixed spot.

(declaim (ftype (function (single-float single-float single-float) single-float) lerp))
(defun lerp (a b tt)
  (+ a (* (- b a) tt)))

(declaim (ftype (function (single-float) single-float) ease-out-cubic))
(defun ease-out-cubic (tt)
  "Starts fast, settles in slow — the standard 'this landed here'
easing curve for UI motion."
  (- 1.0 (expt (- 1.0 tt) 3)))

(defstruct tween
  (start-x 0.0 :type single-float)
  (start-y 0.0 :type single-float)
  (end-x 0.0 :type single-float)
  (end-y 0.0 :type single-float)
  (start-time 0.0d0 :type double-float)
  (duration 0.3 :type single-float))

(declaim (ftype (function (tween double-float) (values single-float single-float)) tween-position))
(defun tween-position (tween now)
  "Returns (values x y) for TWEEN at time NOW, clamped to the tween's
[start-time, start-time+duration] window and eased with
EASE-OUT-CUBIC — never overshoots the end position, never goes
negative before the start."
  (let* ((elapsed (float (- now (tween-start-time tween)) 1.0))
         (raw-tt (max 0.0 (min 1.0 (/ elapsed (tween-duration tween)))))
         (eased-tt (ease-out-cubic raw-tt)))
    (values (lerp (tween-start-x tween) (tween-end-x tween) eased-tt)
            (lerp (tween-start-y tween) (tween-end-y tween) eased-tt))))

(declaim (ftype (function (tween double-float) boolean) tween-finished-p))
(defun tween-finished-p (tween now)
  (>= (- now (tween-start-time tween)) (tween-duration tween)))
