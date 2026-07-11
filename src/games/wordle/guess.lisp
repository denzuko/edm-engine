(in-package :edm-engine/games/wordle)

(declaim (optimize (speed 3) (safety 3)))

(declaim (ftype (function (string string) (simple-vector)) evaluate-guess))
(defun evaluate-guess (guess answer)
  "Standard two-pass Wordle scoring. Pass 1 marks exact-position matches
green and removes them from ANSWER's letter pool. Pass 2 marks remaining
GUESS letters yellow while the pool has that letter left, gray otherwise —
this is what correctly caps yellow count on repeated letters."
  (let* ((len (length guess))
         (result (make-array len :initial-element :gray))
         (pool (make-hash-table)))
    (dotimes (i len)
      (if (char= (char guess i) (char answer i))
          (setf (aref result i) :green)
          (incf (gethash (char answer i) pool 0))))
    (dotimes (i len)
      (unless (eq (aref result i) :green)
        (let ((c (char guess i)))
          (when (plusp (gethash c pool 0))
            (setf (aref result i) :yellow)
            (decf (gethash c pool))))))
    result))

(declaim (ftype (function (list list) list) filter-candidates))
(defun filter-candidates (corpus history)
  "Narrows CORPUS to words consistent with every (guess . feedback) pair in
HISTORY, via a TRANSDUCERS filter pipeline."
  (flet ((consistent-p (candidate)
           (every (lambda (entry)
                    (equalp (evaluate-guess (car entry) candidate) (cdr entry)))
                  history)))
    (transducers:transduce (transducers:filter #'consistent-p)
                            #'transducers:cons corpus)))
