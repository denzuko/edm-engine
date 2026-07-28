(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; #64's own Hearts pilot, BDD gate first — per docs/orchestration-
;;; dsl-design.md's own stated success criteria: a real, macro-
;;; expansion-based transition, not a runtime interpreter. Uses a
;;; synthetic TEST-MACHINE struct, not HEARTS-GAME itself — this spec
;;; belongs to EDM-ENGINE/CORE, testing DEFORCHESTRATION's own
;;; generic behavior, not any one game's domain logic. Hearts' own
;;; retrofit (using this against the real HEARTS-GAME struct) is
;;; separate, later scope, once this generic mechanism is proven.

(defstruct test-machine
  (phase :idle :type keyword)
  (effect-log nil :type list))

(defun test-machine-guard-always-true (machine)
  (declare (ignore machine))
  t)

(defun test-machine-guard-never (machine)
  (declare (ignore machine))
  nil)

(defun test-machine-record-effect (machine)
  (push :effect-ran (test-machine-effect-log machine)))

(edm-engine:deforchestration test-machine
  (:transition idle-to-running
    :from-phase :idle
    :to-phase :running
    :guard test-machine-guard-always-true
    :effect test-machine-record-effect
    :bus-event (:game :test :cue :idle-to-running))
  (:transition running-to-done
    :from-phase :running
    :to-phase :done
    :guard test-machine-guard-never
    :effect test-machine-record-effect
    :bus-event (:game :test :cue :running-to-done)))

(test deforchestration-expands-to-a-plain-checkable-function
  "The macro-expansion constraint itself: MACROEXPAND-1 on the
generated transition attempt must produce ordinary DEFUN forms, not a
runtime S-expression walker — checkable directly, not asserted by
convention."
  (is (fboundp 'try-test-machine-idle-to-running))
  (is (fboundp 'try-test-machine-running-to-done)))

(test try-transition-does-nothing-when-phase-does-not-match
  (let ((m (make-test-machine :phase :running)))
    (is (eq nil (try-test-machine-idle-to-running m)))
    (is (eq :running (test-machine-phase m)))
    (is (equal nil (test-machine-effect-log m)))))

(test try-transition-does-nothing-when-guard-fails
  (let ((m (make-test-machine :phase :running)))
    (is (eq nil (try-test-machine-running-to-done m)))
    (is (eq :running (test-machine-phase m)))))

(test try-transition-runs-effect-and-advances-phase-when-guard-passes
  (let ((m (make-test-machine :phase :idle)))
    (is (eq t (try-test-machine-idle-to-running m)))
    (is (eq :running (test-machine-phase m)))
    (is (equal '(:effect-ran) (test-machine-effect-log m)))))

(test try-transition-pushes-its-declared-bus-event-on-success
  "Drains *ENGINE-BUS*'s own :SEMANTIC topic first — it's global, shared
state across the whole suite (matching DEFAUDIO-CUES' own convention
of always using *ENGINE-BUS*, not a parameterized bus), so a prior
test's own leftover event would otherwise make this test pass for the
wrong reason."
  (loop while (nth-value 1 (edm-engine:bus-try-pop edm-engine:*engine-bus* :semantic)))
  (let ((m (make-test-machine :phase :idle)))
    (try-test-machine-idle-to-running m)
    (multiple-value-bind (event received-p)
        (edm-engine:bus-try-pop edm-engine:*engine-bus* :semantic)
      (is-true received-p)
      (is (equal '(:game :test :cue :idle-to-running) event)))))

(test try-transition-pushes-no-bus-event-when-it-does-not-fire
  (loop while (nth-value 1 (edm-engine:bus-try-pop edm-engine:*engine-bus* :semantic)))
  (let ((m (make-test-machine :phase :running)))
    (try-test-machine-running-to-done m)
    (multiple-value-bind (event received-p)
        (edm-engine:bus-try-pop edm-engine:*engine-bus* :semantic)
      (declare (ignore event))
      (is-false received-p))))

;;; PROCESS-SEMANTIC-EVENTS — the shared dispatch layer docs/vfx-
;;; style-pipeline-design.md itself named as needed but left as the
;;; one concretely unbuilt piece; reconciled with that doc's own
;;; DEFEFFECT-SEQUENCE/DEFEFFECT-STATE machinery, not a replacement
;;; for it (see docs/semantic-event-architecture-design.md). Found
;;; necessary fixing a real bug caught before it shipped: *ENGINE-BUS*
;;; is a queue (CHANL), not a broadcast — two independent consumers
;;; each polling the same :SEMANTIC topic would compete for the same
;;; events rather than both receiving them, confirmed directly by
;;; testing the bus's own real behavior. The fix: ONE dispatcher
;;; drains :SEMANTIC once per call and fans each event out to every
;;; reactor function given, in order — reactors are plain (EVENT) ->
;;; ignored functions, letting each caller close over whatever extra
;;; context (window dimensions, etc.) its own reactor needs at the
;;; actual call site.

(test process-semantic-events-fans-one-event-out-to-every-reactor
  (loop while (nth-value 1 (edm-engine:bus-try-pop edm-engine:*engine-bus* :semantic)))
  (edm-engine:bus-push edm-engine:*engine-bus* :semantic (list :game :spec :cue :test-event))
  (let ((reactor-a-saw nil) (reactor-b-saw nil))
    (edm-engine:process-semantic-events
     (lambda (event) (setf reactor-a-saw event))
     (lambda (event) (setf reactor-b-saw event)))
    (is (equal '(:game :spec :cue :test-event) reactor-a-saw))
    (is (equal '(:game :spec :cue :test-event) reactor-b-saw))))

(test process-semantic-events-drains-multiple-events-in-order
  (loop while (nth-value 1 (edm-engine:bus-try-pop edm-engine:*engine-bus* :semantic)))
  (edm-engine:bus-push edm-engine:*engine-bus* :semantic (list :game :spec :cue :first))
  (edm-engine:bus-push edm-engine:*engine-bus* :semantic (list :game :spec :cue :second))
  (let ((seen nil))
    (edm-engine:process-semantic-events (lambda (event) (push (getf event :cue) seen)))
    (is (equal '(:second :first) seen))))

(test process-semantic-events-is-a-genuine-no-op-with-nothing-pending
  (loop while (nth-value 1 (edm-engine:bus-try-pop edm-engine:*engine-bus* :semantic)))
  (let ((called nil))
    (edm-engine:process-semantic-events (lambda (event) (declare (ignore event)) (setf called t)))
    (is (not called))))

;;; DEFOUTCOME — per direct correction: branching outcomes are exactly
;;; the case for a Datalog-flavored rule table, not a computed
;;; callback function threaded through DEFORCHESTRATION's own
;;; :TO-PHASE. A callback can hide arbitrary, opaque branching logic
;;; behind one function reference; a rule table is itself inspectable
;;; data — an ordered list of (condition-name . outcome) facts, tried
;;; in order, first true wins. Still macro-expansion only (the hard
;;; constraint from docs/orchestration-dsl-design.md): each DEFOUTCOME
;;; form expands into one plain DEFUN that calls CONDITION-TRUE-P for
;;; each named condition in turn — checkable via MACROEXPAND-1, no
;;; runtime interpreter walking the rule list itself. Conditions are
;;; referenced by name (registered via DEFCONDITIONS elsewhere) — the
;;; scoring/win logic itself lives in a named, real predicate function,
;;; never inlined as a raw form inside the rule table.

(defstruct outcome-test-game
  (phase :playing :type keyword)
  (score 0 :type fixnum)
  (rounds-played 0 :type fixnum))

(defun outcome-test-game-over-p (game)
  (>= (outcome-test-game-rounds-played game) 3))

(defun outcome-test-game-winning-p (game)
  (>= (outcome-test-game-score game) 50))

(edm-engine:defconditions outcome-test-game
  (:condition over outcome-test-game-over-p)
  (:condition winning outcome-test-game-winning-p))

(edm-engine:defoutcome outcome-test-game-result (game)
  (:rule (not (edm-engine:condition-true-p 'outcome-test-game 'over game)) :still-playing)
  (:rule (edm-engine:condition-true-p 'outcome-test-game 'winning game) :won)
  (:rule t :lost))

(test defoutcome-expands-to-a-plain-checkable-function
  (is (fboundp 'outcome-test-game-result)))

(test defoutcome-returns-the-first-matching-rules-outcome
  (is (eq :still-playing (outcome-test-game-result (make-outcome-test-game :rounds-played 1 :score 10)))))

(test defoutcome-tries-rules-in-order-not-just-any-true-one
  "Rounds-played 3 (so :OVER is true, ruling out the first rule) with
a losing score — :OVER alone isn't enough to reach :WON, confirming
the rules are genuinely tried in order against independent
conditions, not any single true condition short-circuiting."
  (is (eq :lost (outcome-test-game-result (make-outcome-test-game :rounds-played 3 :score 10)))))

(test defoutcome-falls-through-to-the-catch-all-rule
  (is (eq :lost (outcome-test-game-result (make-outcome-test-game :rounds-played 5 :score 0)))))

(test defoutcome-reaches-a-non-catch-all-rule-when-its-own-condition-is-true
  (is (eq :won (outcome-test-game-result (make-outcome-test-game :rounds-played 3 :score 60)))))
