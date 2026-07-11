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
