(in-package :edm-engine/tests)
(in-suite :edm-engine)

(test register-game-preserves-registration-order
  (let ((edm-engine::*games* nil))
    (register-game "Wordle" (lambda () :wordle))
    (register-game "Queens" (lambda () :queens))
    (is (equal '("Wordle" "Queens") (mapcar #'game-entry-title *games*)))))

(test register-game-replaces-same-title-in-place
  (let ((edm-engine::*games* nil))
    (register-game "Wordle" (lambda () :first))
    (register-game "Queens" (lambda () :queens))
    (register-game "Wordle" (lambda () :second))
    (is (equal '("Wordle" "Queens") (mapcar #'game-entry-title *games*)))
    (is (eq :second (funcall (game-entry-constructor (first *games*)))))))

(test game-entry-constructor-called-lazily-not-at-registration
  (let ((edm-engine::*games* nil)
        (calls 0))
    (register-game "Counted" (lambda () (incf calls) :instance))
    (is (= 0 calls))
    (funcall (game-entry-constructor (first *games*)))
    (is (= 1 calls))))

(test game-outcome-default-method-is-nil
  (is (null (game-outcome :some-arbitrary-game))))

(defmacro with-temp-save-directory (&body body)
  `(let ((*save-directory* (merge-pathnames
                             (format nil "edm-engine-test-saves-~A/" (random 1000000))
                             (uiop:temporary-directory))))
     (unwind-protect (progn ,@body)
       (when (probe-file *save-directory*)
         (uiop:delete-directory-tree *save-directory* :validate t)))))

(test save-and-load-slot-round-trips
  (with-temp-save-directory
    (save-game-to-slot 0 "Wordle" :fake-game-instance 340)
    (multiple-value-bind (title score timestamp data) (load-game-from-slot 0)
      (is (string= "Wordle" title))
      (is (= 340 score))
      (is (integerp timestamp))
      ;; GAME-SAVE-DATA's default method is NIL for anything without a
      ;; specialized method, like this plain keyword
      (is (null data)))))

(test load-game-from-slot-returns-nil-for-an-empty-slot
  (with-temp-save-directory
    (is (null (load-game-from-slot 5)))))

(test slots-are-independent-of-each-other
  (with-temp-save-directory
    (save-game-to-slot 0 "Wordle" :fake-a 100)
    (save-game-to-slot 3 "Queens" :fake-b 200)
    (is (null (load-game-from-slot 1)))
    (multiple-value-bind (title0) (load-game-from-slot 0) (is (string= "Wordle" title0)))
    (multiple-value-bind (title3) (load-game-from-slot 3) (is (string= "Queens" title3)))))

(test delete-save-slot-clears-it
  (with-temp-save-directory
    (save-game-to-slot 2 "Wordle" :fake-game-instance 50)
    (delete-save-slot 2)
    (is (null (load-game-from-slot 2)))))

(test list-save-slots-reports-all-ten-with-empties-as-nil
  (with-temp-save-directory
    (save-game-to-slot 0 "Wordle" :fake-a 10)
    (save-game-to-slot 7 "Queens" :fake-b 20)
    (let ((slots (list-save-slots)))
      (is (= 10 (length slots)))
      (is (getf (nth 0 slots) :table-title))
      (is (string= "Wordle" (getf (nth 0 slots) :table-title)))
      (is (null (nth 1 slots)))
      (is (string= "Queens" (getf (nth 7 slots) :table-title))))))

(test format-save-timestamp-produces-a-sortable-string
  ;; 2026-01-15 10:30:00 UTC-ish, exact value doesn't matter — format shape does
  (let ((s (format-save-timestamp (encode-universal-time 0 30 10 15 1 2026 0))))
    (is (string= "2026-01-15 10:30" s))))
