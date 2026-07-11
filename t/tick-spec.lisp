(in-package :edm-engine/tests)
(in-suite :edm-engine)

(test advance-tick-integrates-velocity-into-position
  (let* ((arena (make-arena 4))
         (clock (make-tick))
         (h (arena-spawn arena)))
    (arena-set-position arena h 0.0 0.0)
    (arena-set-velocity arena h 2.0 0.0)
    (advance-tick arena clock 0.5)
    (multiple-value-bind (x y) (arena-position arena h)
      (is (= x 1.0))
      (is (= y 0.0)))))

(test advance-tick-increments-frame-counter
  (let* ((arena (make-arena 1))
         (clock (make-tick)))
    (is (= 0 (tick-frame clock)))
    (advance-tick arena clock 0.016)
    (is (= 1 (tick-frame clock)))
    (advance-tick arena clock 0.016)
    (is (= 2 (tick-frame clock)))))

(test advance-tick-skips-despawned-entities
  (let* ((arena (make-arena 2))
         (clock (make-tick))
         (h (arena-spawn arena)))
    (arena-set-position arena h 0.0 0.0)
    (arena-set-velocity arena h 1.0 1.0)
    (arena-despawn arena h)
    (advance-tick arena clock 1.0)
    (is (= 1 (tick-frame clock)))))
