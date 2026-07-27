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
  "Drains *ENGINE-BUS*'s own :AUDIO topic first — it's global, shared
state across the whole suite (matching DEFAUDIO-CUES' own convention
of always using *ENGINE-BUS*, not a parameterized bus), so a prior
test's own leftover event would otherwise make this test pass for the
wrong reason."
  (loop while (nth-value 1 (edm-engine:bus-try-pop edm-engine:*engine-bus* :audio)))
  (let ((m (make-test-machine :phase :idle)))
    (try-test-machine-idle-to-running m)
    (multiple-value-bind (event received-p)
        (edm-engine:bus-try-pop edm-engine:*engine-bus* :audio)
      (is-true received-p)
      (is (equal '(:game :test :cue :idle-to-running) event)))))

(test try-transition-pushes-no-bus-event-when-it-does-not-fire
  (loop while (nth-value 1 (edm-engine:bus-try-pop edm-engine:*engine-bus* :audio)))
  (let ((m (make-test-machine :phase :running)))
    (try-test-machine-running-to-done m)
    (multiple-value-bind (event received-p)
        (edm-engine:bus-try-pop edm-engine:*engine-bus* :audio)
      (declare (ignore event))
      (is-false received-p))))
