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
