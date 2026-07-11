(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

(defstruct (tick (:constructor make-tick))
  "Engine clock. FRAME increments once per ADVANCE-TICK call."
  (frame 0 :type (unsigned-byte 64)))

(defun ensure-kernel (&key (worker-count 4))
  "Idempotent LPARALLEL kernel bring-up for the calling image."
  (unless lparallel:*kernel*
    (setf lparallel:*kernel* (lparallel:make-kernel worker-count))))

(declaim (ftype (function (arena tick single-float) (unsigned-byte 64)) advance-tick))
(defun advance-tick (arena tick dt)
  "Integrate velocity into position for every live entity, in parallel via
LPARALLEL over a TRANSDUCERS-gathered handle set. Returns the new frame count."
  (ensure-kernel)
  (let ((handles (arena-live-handles arena)))
    (lparallel:pmap nil
                     (lambda (h)
                       (multiple-value-bind (x y) (arena-position arena h)
                         (multiple-value-bind (vx vy) (arena-velocity arena h)
                           (arena-set-position arena h (+ x (* vx dt)) (+ y (* vy dt))))))
                     handles))
  (incf (tick-frame tick)))
