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

;; #32's own real retrofit — DEFINE-TIMED-STRUCT proven against
;; TWEEN's own already-correct START-TIME/DURATION fields (both were
;; already DOUBLE-FLOAT; this doesn't change TWEEN's own behavior at
;; all, only makes it impossible for a future edit to accidentally
;; regress either field back to SINGLE-FLOAT without a macro-
;; expansion-time error).
(define-timed-struct tween (start-time duration)
  (start-x 0.0 :type single-float)
  (start-y 0.0 :type single-float)
  (end-x 0.0 :type single-float)
  (end-y 0.0 :type single-float)
  (start-time 0.0d0 :type double-float)
  (duration 0.3d0 :type double-float))

(declaim (ftype (function (tween double-float) (values single-float single-float)) tween-position))
(defun tween-position (tween now)
  "Returns (values x y) for TWEEN at time NOW, clamped to the tween's
[start-time, start-time+duration] window and eased with
EASE-OUT-CUBIC — never overshoots the end position, never goes
negative before the start."
  (let* ((elapsed (- now (tween-start-time tween)))
         (raw-tt (max 0.0d0 (min 1.0d0 (/ elapsed (tween-duration tween)))))
         (eased-tt (ease-out-cubic (float raw-tt 1.0))))
    (values (lerp (tween-start-x tween) (tween-end-x tween) eased-tt)
            (lerp (tween-start-y tween) (tween-end-y tween) eased-tt))))

(declaim (ftype (function (tween double-float) boolean) tween-finished-p))
(defun tween-finished-p (tween now)
  (>= (- now (tween-start-time tween)) (tween-duration tween)))

;;; The generic EFFECT protocol — #37's own design doc names this
;;; directly, TWEEN as the first concrete implementation. One shared
;;; interface future effect types (camera shake, particle bursts)
;;; implement, matching GAME-PROTOCOL.LISP's established style
;;; (generic functions, default methods where sensible), instead of
;;; being unrelated ad hoc systems each reinventing timing.

(defgeneric effect-update (effect now)
  (:documentation "Advances EFFECT's own internal state to NOW, for
effect types that have state to advance (a particle system's physics
tick). Default no-op — TWEEN-POSITION is already a pure function of
NOW, nothing for TWEEN itself to advance here.")
  (:method (effect now) (declare (ignore effect now)) nil))

(defgeneric effect-finished-p (effect now)
  (:documentation "Whether EFFECT is done as of NOW. No default
method — every real effect type must define what \"finished\" means
for itself; there's no sensible universal default the way
EFFECT-UPDATE's no-op is."))

(defgeneric effect-apply (effect now)
  (:documentation "Whatever \"applying\" EFFECT means as of NOW — a
position for a tween, a shake magnitude for camera shake, a draw call
for a particle burst. No default method, same reasoning as
EFFECT-FINISHED-P."))

(defmethod effect-finished-p ((effect tween) now)
  (tween-finished-p effect now))

(defmethod effect-apply ((effect tween) now)
  (tween-position effect now))

;;; VALUE-TWEEN — #46's own generalization of TWEEN to an N-
;;; dimensional, array-based value interpolator (scale, rotation,
;;; alpha, color — not just a hardcoded 2D position). One real
;;; correction to #46's own draft sketch, made here rather than
;;; implemented as originally written: that sketch specified DOUBLE-
;;; FLOAT for the interpolated values themselves, written before this
;;; session's own float-consistency retrofit (docs/layout-float-
;;; consistency-and-gpu-tweens-design.md) established SINGLE-FLOAT as
;;; the standard for coordinate/visual values throughout this engine —
;;; matching the arena's own storage, raylib itself, ANCHOR-AT-EDGE.
;;; #31's own DOUBLE-FLOAT lesson was specifically about TIME values
;;; compared against RAYLIB:GET-TIME; START-TIME/DURATION stay
;;; DOUBLE-FLOAT here too, matching TWEEN's own already-correct
;;; convention — only the interpolated payload itself changes from
;;; the original sketch.

(define-timed-struct value-tween (start-time duration)
  (start-values (make-array 0 :element-type 'single-float) :type (simple-array single-float (*)))
  (end-values (make-array 0 :element-type 'single-float) :type (simple-array single-float (*)))
  (start-time 0.0d0 :type double-float)
  (duration 0.3d0 :type double-float)
  (easing-fn #'ease-out-cubic :type function))

(declaim (ftype (function (value-tween double-float) (simple-array single-float (*))) value-tween-values))
(defun value-tween-values (value-tween now)
  "Returns a fresh vector, one interpolated entry per START-VALUES/
END-VALUES pair, at time NOW — clamped and eased the same way TWEEN-
POSITION already is, generalized to however many dimensions this
particular VALUE-TWEEN holds."
  (let* ((elapsed (- now (value-tween-start-time value-tween)))
         (raw-tt (max 0.0d0 (min 1.0d0 (/ elapsed (value-tween-duration value-tween)))))
         (eased-tt (funcall (value-tween-easing-fn value-tween) (float raw-tt 1.0)))
         (starts (value-tween-start-values value-tween))
         (ends (value-tween-end-values value-tween)))
    (map '(simple-array single-float (*)) (lambda (s e) (lerp s e eased-tt)) starts ends)))

(declaim (ftype (function (value-tween double-float) boolean) value-tween-finished-p))
(defun value-tween-finished-p (value-tween now)
  (>= (- now (value-tween-start-time value-tween)) (value-tween-duration value-tween)))

(defmethod effect-finished-p ((effect value-tween) now)
  (value-tween-finished-p effect now))

(defmethod effect-apply ((effect value-tween) now)
  (value-tween-values effect now))
