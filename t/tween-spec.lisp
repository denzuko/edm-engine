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
                         :start-time 10.0d0 :duration 0.5)))
    (multiple-value-bind (x y) (tween-position tw 10.0d0)
      (is (= 0.0 x))
      (is (= 0.0 y)))))

(test tween-position-at-end-time-is-the-end-position
  (let ((tw (make-tween :start-x 0.0 :start-y 0.0 :end-x 100.0 :end-y 50.0
                         :start-time 10.0d0 :duration 0.5)))
    (multiple-value-bind (x y) (tween-position tw 10.5d0)
      (is (= 100.0 x))
      (is (= 50.0 y)))))

(test tween-position-past-end-time-clamps-to-end-not-overshoot
  (let ((tw (make-tween :start-x 0.0 :start-y 0.0 :end-x 100.0 :end-y 50.0
                         :start-time 10.0d0 :duration 0.5)))
    (multiple-value-bind (x y) (tween-position tw 20.0d0)
      (is (= 100.0 x))
      (is (= 50.0 y)))))

(test tween-position-before-start-time-clamps-to-start
  (let ((tw (make-tween :start-x 5.0 :start-y 5.0 :end-x 100.0 :end-y 50.0
                         :start-time 10.0d0 :duration 0.5)))
    (multiple-value-bind (x y) (tween-position tw 1.0d0)
      (is (= 5.0 x))
      (is (= 5.0 y)))))

(test tween-finished-p-true-once-duration-elapsed
  (let ((tw (make-tween :start-x 0.0 :start-y 0.0 :end-x 1.0 :end-y 1.0
                         :start-time 0.0d0 :duration 0.5)))
    (is (not (tween-finished-p tw 0.3d0)))
    (is (tween-finished-p tw 0.5d0))
    (is (tween-finished-p tw 1.0d0))))
