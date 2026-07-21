(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; SAVE.LISP had zero test coverage before this file — checked
;;; directly (no t/save-spec.lisp existed anywhere). *SAVE-DIRECTORY*
;;; is rebound to a real temp directory per test, not mocked, so these
;;; genuinely exercise real file I/O.

(defmacro with-temp-save-directory (&body body)
  `(let ((*save-directory* (merge-pathnames (format nil "edm-engine-save-test-~A/" (random 1000000))
                                             (uiop:temporary-directory))))
     (unwind-protect (progn ,@body)
       (ignore-errors (uiop:delete-directory-tree *save-directory* :validate t)))))

(defclass spec-save-game () ((data :initarg :data :accessor spec-save-game-data)))
(defmethod game-save-data ((g spec-save-game)) (spec-save-game-data g))

(test save-game-to-slot-then-load-round-trips-exactly
  "GOAL: what SAVE-GAME-TO-SLOT writes is exactly what LOAD-GAME-FROM-
SLOT reads back — the basic contract every other spec here assumes
holds."
  (with-temp-save-directory
    (save-game-to-slot 0 "Queens" (make-instance 'spec-save-game :data 100) 42)
    (multiple-value-bind (title score timestamp data) (load-game-from-slot 0)
      (declare (ignore timestamp))
      (is (string= "Queens" title))
      (is (= 42 score))
      (is (= 100 data)))))

(test load-game-from-slot-returns-nil-for-a-genuinely-empty-slot
  (with-temp-save-directory
    (is (null (load-game-from-slot 5)))))

;;; #9's remaining scope — LOAD-GAME-FROM-SLOT had zero error handling:
;;; a corrupted or malformed save file threw an unhandled reader error,
;;; and since LIST-SAVE-SLOTS calls this for every slot, one bad file
;;; broke browsing every slot, not just the corrupted one. BDD-first,
;;; written before the fix exists.

(test load-game-from-slot-does-not-signal-on-a-genuinely-corrupted-file
  "GOAL: a real, malformed sexp (unbalanced parens, truncated mid-
write — a real failure mode, not a contrived one) must not signal an
unhandled error, matching the existing NIL-for-empty-slot contract
rather than a new, special error path the rest of the code would need
its own handling for. Uses FINISHES, not a local IGNORE-ERRORS wrapper
around the call — a local wrapper would mask whether LOAD-GAME-FROM-
SLOT itself handles the error, making the test pass regardless of
whether the fix exists, a real flaw caught in this test's own first
draft before it was run."
  (with-temp-save-directory
    (ensure-save-directory)
    (with-open-file (out (save-slot-data-path 0) :direction :output :if-does-not-exist :create)
      (write-string "(:table-title \"Queens\" :score 5 :data (" out)) ; deliberately truncated, unbalanced parens
    (finishes (load-game-from-slot 0))))

(test load-game-from-slot-returns-nil-not-a-partial-value-on-a-corrupted-file
  "GOAL: a corrupted slot behaves exactly like an empty one to every
caller — LIST-SAVE-SLOTS' own NIL-means-empty convention, not a
different, special case it would need to check for separately."
  (with-temp-save-directory
    (ensure-save-directory)
    (with-open-file (out (save-slot-data-path 0) :direction :output :if-does-not-exist :create)
      (write-string "not even a valid sexp at all }{" out))
    (is (null (load-game-from-slot 0)))))

(test list-save-slots-skips-a-corrupted-slot-rather-than-breaking-every-other-slot
  "GOAL: the actual real-world impact of the bug this fixes — one
corrupted slot must not prevent the other, genuinely valid slots from
listing correctly, checked as the real, combined scenario rather than
LOAD-GAME-FROM-SLOT's own contract assumed to compose correctly."
  (with-temp-save-directory
    (save-game-to-slot 0 "Queens" (make-instance 'spec-save-game :data 1) 10)
    (ensure-save-directory)
    (with-open-file (out (save-slot-data-path 1) :direction :output :if-does-not-exist :create)
      (write-string "(:corrupted" out))
    (save-game-to-slot 2 "Hearts" (make-instance 'spec-save-game :data 2) 20)
    (let ((slots (list-save-slots)))
      (is (getf (nth 0 slots) :table-title))
      (is (null (nth 1 slots)))
      (is (getf (nth 2 slots) :table-title)))))
