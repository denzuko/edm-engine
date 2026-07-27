(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; The Datalog/ruleset-corpus reconciliation with #64's own hard
;;; constraint (macro-expansion only, never a runtime interpreter):
;;; DEFCONDITIONS is the same registry shape already proven by
;;; DEFAUDIO-CUES (a (GAME . NAME) -> value hash table, populated at
;;; macro-expansion time) — but here the registered value is a real,
;;; already-compiled predicate function, not inert data. CONDITION-
;;; TRUE-P is a genuine name-based query surface (the "event handler
;;; checks game state conditions" Den asked for) that dispatches to
;;; that real function — never walks an S-expression fact base at
;;; runtime. Uses a synthetic game struct, not HEARTS-GAME — this
;;; spec belongs to EDM-ENGINE/CORE, testing the registry's own
;;; generic behavior; Hearts' own retrofit (registering ROUND-OVER-P/
;;; GAME-OVER-P under real names) is separate, later scope.

(defstruct condition-test-game
  (score 0 :type fixnum))

(defun condition-test-game-score-over-100-p (game)
  (> (condition-test-game-score game) 100))

(defun condition-test-game-score-is-zero-p (game)
  (= 0 (condition-test-game-score game)))

(edm-engine:defconditions condition-test-game
  (:condition score-over-100 condition-test-game-score-over-100-p)
  (:condition score-is-zero condition-test-game-score-is-zero-p))

(test defconditions-registers-a-condition-resolvable-by-game-and-name
  (is (eq t (edm-engine:condition-true-p 'condition-test-game 'score-is-zero
                                          (make-condition-test-game :score 0)))))

(test condition-true-p-returns-nil-when-the-predicate-is-false
  (is (eq nil (edm-engine:condition-true-p 'condition-test-game 'score-over-100
                                            (make-condition-test-game :score 5)))))

(test condition-true-p-genuinely-calls-the-registered-predicate-each-time
  "Not a cached, one-time snapshot — the same condition name against
two different game instances gives two different, correct answers."
  (is (eq nil (edm-engine:condition-true-p 'condition-test-game 'score-over-100
                                            (make-condition-test-game :score 5))))
  (is (eq t (edm-engine:condition-true-p 'condition-test-game 'score-over-100
                                          (make-condition-test-game :score 200)))))

(test condition-true-p-signals-a-clear-error-for-an-unregistered-condition
  "Unlike RESOLVE-AUDIO-CUE's own NIL-for-unavailable convention (a
missing sound cue is a harmless no-op), a missing game-state condition
means the orchestration logic itself has a typo or a stale reference
— genuinely different failure semantics, so this signals rather than
silently returns NIL, matching the principle that a wrong answer
about game state is worse than a loud, immediate error."
  (signals error
    (edm-engine:condition-true-p 'condition-test-game 'genuinely-never-registered
                                  (make-condition-test-game))))
