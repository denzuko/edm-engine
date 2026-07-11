(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

(defconstructor handle
  "An entity reference: a slot INDEX paired with a GENERATION counter.
Guards against stale handles into a recycled arena slot."
  (index (unsigned-byte 32))
  (generation (unsigned-byte 32)))

(declaim (ftype (function (handle handle) boolean) handle=))
(defun handle= (a b)
  (and (= (handle-index a) (handle-index b))
       (= (handle-generation a) (handle-generation b))))
