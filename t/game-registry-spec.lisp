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

(test save-and-load-game-round-trips
  (let ((path (merge-pathnames (format nil "edm-engine-test-~A.sexp" (random 1000000))
                                (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (save-game-to-file "Wordle" :fake-game-instance 340 path)
           (multiple-value-bind (title score data) (load-game-from-file path)
             (is (string= "Wordle" title))
             (is (= 340 score))
             ;; GAME-SAVE-DATA's default method is NIL for anything
             ;; without a specialized method, like this plain keyword
             (is (null data))))
      (when (probe-file path) (delete-file path)))))

(test load-game-from-file-returns-nil-for-a-missing-path
  (let ((path (merge-pathnames "edm-engine-definitely-does-not-exist.sexp"
                                (uiop:temporary-directory))))
    (is (null (load-game-from-file path)))))
