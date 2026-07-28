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

;;; DEFOUTCOME — branching outcomes as a declarative decision table,
;;; not a computed callback function. Per direct correction: a
;;; callback (e.g. DEFORCHESTRATION's own :TO-PHASE taking an
;;; arbitrary function) can hide opaque branching logic behind one
;;; function reference; a rule table is itself inspectable data — an
;;; ordered list of (condition-name . outcome) facts, tried in order,
;;; first true wins, the same shape General Game Playing's own Game
;;; Description Language uses (a Datalog variant: game states as fact
;;; sets, outcomes as rules derived bottom-up from them) — real
;;; precedent, not invented for this project. Still macro-expansion
;;; only: expands into one plain DEFUN calling CONDITION-TRUE-P for
;;; each named condition in turn, checkable via MACROEXPAND-1, no
;;; runtime interpreter walking the rule list itself. Set theory over
;;; finite fact sets, not measure theory or probability — Hearts' own
;;; state space is finite and outcomes are deterministic given the
;;; fact set, not a stochastic estimate over an infinite/continuous
;;; space; reaching for measure theory would claim machinery this
;;; domain doesn't need.

(defmacro defoutcome (name (game-var) &body rules)
  "Defines NAME (GAME-VAR): tries each (:RULE CONDITION-FORM RESULT)
in RULES in order, with GAME-VAR bound to the function's own
argument; the first CONDITION-FORM that's true returns RESULT
(evaluated). CONDITION-FORM is typically a CONDITION-TRUE-P call
against a named, registered condition — RULES themselves stay
declarative facts, not a place to inline a game's own scoring logic;
that logic lives in a named predicate registered via DEFCONDITIONS,
referenced here by name."
  `(defun ,name (,game-var)
     (declare (ignorable ,game-var))
     (cond ,@(loop for (rule-keyword condition-form result) in rules
                   collect `(,condition-form ,result)))))
