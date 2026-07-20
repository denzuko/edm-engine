(in-package :edm-engine/tests)
(in-suite :edm-engine)

(test lerp-interpolates-linearly
  (is (= 5.0 (lerp 0.0 10.0 0.5)))
  (is (= 0.0 (lerp 0.0 10.0 0.0)))
  (is (= 10.0 (lerp 0.0 10.0 1.0))))

(test ease-out-cubic-starts-fast-ends-slow
  "Ease-out: early progress covers MORE ground than an equal later
step — the defining shape of the curve, not just 'some nonlinear
function'."
  (let ((step1 (- (ease-out-cubic 0.3) (ease-out-cubic 0.0)))
        (step2 (- (ease-out-cubic 1.0) (ease-out-cubic 0.7))))
    (is (> step1 step2))))

(test ease-out-cubic-endpoints-are-exact
  (is (= 0.0 (ease-out-cubic 0.0)))
  (is (= 1.0 (ease-out-cubic 1.0))))

(test make-tween-position-at-start-time-is-the-start-position
  (let ((tw (make-tween :start-x 0.0 :start-y 0.0 :end-x 100.0 :end-y 50.0
                         :start-time 10.0d0 :duration 0.5d0)))
    (multiple-value-bind (x y) (tween-position tw 10.0d0)
      (is (= 0.0 x))
      (is (= 0.0 y)))))

(test tween-position-at-end-time-is-the-end-position
  (let ((tw (make-tween :start-x 0.0 :start-y 0.0 :end-x 100.0 :end-y 50.0
                         :start-time 10.0d0 :duration 0.5d0)))
    (multiple-value-bind (x y) (tween-position tw 10.5d0)
      (is (= 100.0 x))
      (is (= 50.0 y)))))

(test tween-position-past-end-time-clamps-to-end-not-overshoot
  (let ((tw (make-tween :start-x 0.0 :start-y 0.0 :end-x 100.0 :end-y 50.0
                         :start-time 10.0d0 :duration 0.5d0)))
    (multiple-value-bind (x y) (tween-position tw 20.0d0)
      (is (= 100.0 x))
      (is (= 50.0 y)))))

(test tween-position-before-start-time-clamps-to-start
  (let ((tw (make-tween :start-x 5.0 :start-y 5.0 :end-x 100.0 :end-y 50.0
                         :start-time 10.0d0 :duration 0.5d0)))
    (multiple-value-bind (x y) (tween-position tw 1.0d0)
      (is (= 5.0 x))
      (is (= 5.0 y)))))

(test tween-finished-p-true-once-duration-elapsed
  (let ((tw (make-tween :start-x 0.0 :start-y 0.0 :end-x 1.0 :end-y 1.0
                         :start-time 0.0d0 :duration 0.5d0)))
    (is (not (tween-finished-p tw 0.3d0)))
    (is (tween-finished-p tw 0.5d0))
    (is (tween-finished-p tw 1.0d0))))

(test tween-finished-p-correct-at-exact-precision-sensitive-boundary
  "Regression test for a real, live-verified bug (#31): DURATION was
originally SINGLE-FLOAT while compared against a DOUBLE-FLOAT elapsed
time — widening single to double doesn't gain precision, so this exact
boundary (0.3 duration from a 10.0 start) returned NIL when it should
have returned T. Locking in the specific case that was found broken,
not just the general shape already covered above."
  (let ((tw (make-tween :start-time 10.0d0 :duration 0.3d0)))
    (is (tween-finished-p tw 10.3d0))))

;;; The generic EFFECT protocol — #37's own design doc names this
;;; directly (EFFECT-UPDATE/EFFECT-FINISHED-P/EFFECT-APPLY), TWEEN as
;;; the first concrete implementation, matching GAME-PROTOCOL.LISP's
;;; established style. #31 itself is already fixed (closed) — this is
;;; the separate, real remaining piece: one shared interface future
;;; effect types (camera shake, particle bursts) implement, instead of
;;; being unrelated ad hoc systems each reinventing timing, per the
;;; design doc's own stated goal. BDD-first, written before the
;;; generic functions/TWEEN methods exist.

(test effect-apply-on-a-tween-matches-tween-position-directly
  "GOAL: the generic protocol composes TWEEN-POSITION, it doesn't
reimplement the interpolation math a second time under a new name."
  (let ((tw (make-tween :start-x 0.0 :start-y 0.0 :end-x 100.0 :end-y 200.0
                         :start-time 0.0d0 :duration 1.0d0)))
    (multiple-value-bind (ex ey) (effect-apply tw 0.5d0)
      (multiple-value-bind (tx ty) (tween-position tw 0.5d0)
        (is (= ex tx))
        (is (= ey ty))))))

(test effect-finished-p-on-a-tween-matches-tween-finished-p-directly
  "Same composition principle as EFFECT-APPLY above, checked
independently for EFFECT-FINISHED-P rather than assumed shared just
because both wrap TWEEN functions."
  (let ((tw (make-tween :start-time 10.0d0 :duration 0.3d0)))
    (is (eq (tween-finished-p tw 10.3d0) (effect-finished-p tw 10.3d0)))))

(test effect-update-on-a-tween-is-a-genuine-no-op-not-an-error
  "GOAL: TWEEN has no internal state EFFECT-UPDATE needs to advance —
TWEEN-POSITION is already a pure function of NOW, unlike a future
stateful effect type (a particle system's own physics tick). The
generic default method must exist and do nothing harmful for a type
with nothing to update, not signal a NO-APPLICABLE-METHOD error that
would force every effect type to define a method even when there's
truly nothing to do."
  (let ((tw (make-tween :start-time 0.0d0 :duration 1.0d0)))
    (is (not (null (nth-value 0 (ignore-errors (effect-update tw 0.5d0) t)))))))
