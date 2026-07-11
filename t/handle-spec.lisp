(in-package :edm-engine/tests)
(in-suite :edm-engine)

(test handle-equality-compares-index-and-generation
  (is (handle= (handle 3 0) (handle 3 0)))
  (is (not (handle= (handle 3 0) (handle 3 1))))
  (is (not (handle= (handle 3 0) (handle 4 0)))))
