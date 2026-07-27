(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

;;; DEFCONDITIONS — the Datalog/ruleset-corpus reconciliation with
;;; #64's own hard constraint (macro-expansion only, never a runtime
;;; interpreter). Same registry shape as DEFAUDIO-CUES — a
;;; (GAME . NAME) -> value hash table, populated at macro-expansion
;;; time — but the registered value here is a real, already-compiled
;;; predicate function symbol, not inert data. CONDITION-TRUE-P is a
;;; genuine name-based query surface: any consumer (an orchestration
;;; guard, render.lisp's own legality-dimming logic, a future AI
;;; heuristic) can ask "is CONDITION true for this GAME" by name,
;;; without needing to import or know the underlying predicate
;;; function's own symbol — but the dispatch itself always resolves
;;; to calling a real function, never walking an S-expression fact
;;; base at runtime.

(defvar *conditions* (make-hash-table :test 'equal)
  "Maps (GAME-STRUCT-NAME . CONDITION-NAME) conses to predicate
function symbols, registered via DEFCONDITIONS.")

(defmacro defconditions (game-struct-name &body conditions)
  "Registers each (CONDITION-NAME PREDICATE-FN) in CONDITIONS under
GAME-STRUCT-NAME in *CONDITIONS*, keyed on (GAME-STRUCT-NAME . NAME)
so two different game structs can reuse the same condition name for
genuinely different predicates without colliding."
  `(progn
     ,@(loop for (nil name predicate) in conditions
             collect `(setf (gethash (cons ',game-struct-name ',name) *conditions*)
                             ',predicate))))

(defun condition-true-p (game-struct-name condition-name game)
  "Looks up (GAME-STRUCT-NAME . CONDITION-NAME) in *CONDITIONS* and
calls the registered predicate with GAME. Signals an error for an
unregistered condition — unlike RESOLVE-AUDIO-CUE's own NIL-for-
unavailable convention (a missing sound is a harmless no-op), a
missing game-state condition means the caller has a typo or a stale
reference, and a wrong answer about game state is worse than a loud,
immediate error."
  (let ((predicate (gethash (cons game-struct-name condition-name) *conditions*)))
    (unless predicate
      (error "No condition ~A registered for ~A" condition-name game-struct-name))
    (funcall predicate game)))
