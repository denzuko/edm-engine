(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

(defgeneric ruleset-load (game)
  (:documentation
   "Called on scene/game entry. Populates a per-game rules engine (SCREAMER,
for genuine constraint-satisfaction games) and returns an opaque handle to
pass to RULESET-UNLOAD. Default is a no-op: most games need no rules engine
at all, only a filter pipeline over a corpus.")
  (:method (game) (declare (ignore game)) nil))

(defgeneric ruleset-unload (game handle)
  (:documentation "Called on scene/game exit. Tears down what RULESET-LOAD built.")
  (:method (game handle) (declare (ignore game handle)) nil))
