(in-package :edm-engine/tests)
(in-suite :edm-engine)

(test bus-push-then-pop-round-trips
  (let ((bus (make-bus)))
    (bus-push bus :spawn :goblin)
    (is (eql :goblin (bus-pop bus :spawn)))))

(test bus-try-pop-on-empty-topic-does-not-block
  (let ((bus (make-bus)))
    (multiple-value-bind (value received-p) (bus-try-pop bus :spawn)
      (declare (ignore value))
      (is (not received-p)))))

(test bus-topics-are-independent
  (let ((bus (make-bus)))
    (bus-push bus :spawn :a)
    (bus-push bus :despawn :b)
    (is (eql :a (bus-pop bus :spawn)))
    (is (eql :b (bus-pop bus :despawn)))))

(test bus-push-and-pop-record-metrics-per-topic
  "#51's first real bus instrumentation — checked directly, not
assumed from the implementation reading correctly. Two different
topics must not share counters."
  (clearMetrics)
  (let ((bus (make-bus)))
    (bus-push bus :metrics-a 1)
    (bus-push bus :metrics-a 2)
    (bus-push bus :metrics-b 1)
    (is (= 2 (btd :metrics-a)))
    (is (= 1 (btd :metrics-b)))
    (bus-pop bus :metrics-a)
    (is (= 1 (btd :metrics-a)))
    (is (= 1 (btd :metrics-b)))))

(test bus-try-pop-on-a-miss-does-not-record-a-spurious-pop
  "A non-blocking poll that finds nothing pending isn't a real pop —
must not decrement depth for a topic that was never pushed to."
  (clearMetrics)
  (let ((bus (make-bus)))
    (multiple-value-bind (value received-p) (bus-try-pop bus :never-pushed)
      (declare (ignore value received-p)))
    (is (= 0 (btd :never-pushed)))))

(test bus-topic-depth-is-zero-for-an-untouched-topic
  (clearMetrics)
  (is (= 0 (btd :completely-unused))))
