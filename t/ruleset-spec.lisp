(in-package :edm-engine/tests)
(in-suite :edm-engine)

(test ruleset-default-methods-are-no-ops
  (let ((handle (ruleset-load :some-game)))
    (is (null handle))
    (is (null (ruleset-unload :some-game handle)))))

(defclass spec-queens-game () ())

(defmethod ruleset-load ((game spec-queens-game))
  :queens-engine-handle)

(defmethod ruleset-unload ((game spec-queens-game) handle)
  (declare (ignore handle))
  :unloaded)

(test ruleset-per-game-override-round-trips
  (let* ((game (make-instance 'spec-queens-game))
         (handle (ruleset-load game)))
    (is (eql :queens-engine-handle handle))
    (is (eql :unloaded (ruleset-unload game handle)))))
