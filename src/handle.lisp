(in-package :edm-engine)


(defconstructor handle
  "An entity reference: a slot INDEX paired with a GENERATION counter.
Guards against stale handles into a recycled arena slot."
  (index (unsigned-byte 32))
  (generation (unsigned-byte 32)))

(declaim (ftype (function (handle handle) boolean) handle=))
(defun handle= (a b)
  (and (= (handle-index a) (handle-index b))
       (= (handle-generation a) (handle-generation b))))
