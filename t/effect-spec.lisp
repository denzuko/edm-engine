(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; BDD — the goal gate, per docs/test-layer-separation.md. Written
;;; before PULSEVAL/ESE existed, expected to fail with
;;; UNDEFINED-FUNCTION until implemented — the goal, not a regression
;;; test added after the fact. #37's DEFEFFECT-STATE design names this
;;; exact case (Queens' cursor pulse, generalized) as its own worked
;;; example.
;;;
;;; Deliberately broad, not exact arithmetic — precise correctness
;;; (Queens' formula matched at specific points, exact elapsed-time
;;; values) lives in t/effect-impl-spec.lisp instead. This file is a
;;; durable statement of intent, not a scratchpad for working out
;;; exact values — that split is the actual point of this file's own
;;; restructuring, prompted directly by a real miss (a bug found here
;;; was originally fixed by editing this file in place, which is
;;; exactly what the split now prevents).

(test pulse-val-oscillates-rather-than-staying-constant
  "GOAL: a value that changes over time, generalizing Queens' existing
visual pulse effect. Broad — exact points are the TDD layer's job."
  (is (not (= (pulseVal 0.0d0 :period 1.0d0) (pulseVal 0.25d0 :period 1.0d0)))))

(test pulse-val-base-and-amplitude-shift-the-oscillations-range
  "GOAL: BASE/AMPLITUDE let a caller scale the raw 0-1 oscillation into
whatever range it actually needs (Queens' 0.7-1.0 value range), not
leave every caller re-deriving that scaling itself."
  (let ((narrow (pulseVal 0.0d0 :period 1.0d0 :base 0.5 :amplitude 0.1))
        (wide (pulseVal 0.0d0 :period 1.0d0 :base 0.5 :amplitude 0.5)))
    (is (not (= narrow wide)))))

(test ese-reports-a-fresh-near-zero-elapsed-time-on-activation
  "GOAL: a state-triggered effect should start fresh when it becomes
active, not inherit stale timing from somewhere else."
  (clearEse)
  (is (< (ese :bdd-test t 100.0d0) 0.001d0)))

(test ese-elapsed-time-grows-while-active
  "GOAL: once active, elapsed time should genuinely advance, not stay
pinned at zero."
  (clearEse)
  (ese :bdd-test t 100.0d0)
  (is (> (ese :bdd-test t 105.0d0) 0)))

(test ese-reports-inactive-after-deactivation
  "GOAL: a state that's no longer active should report as such, not
silently keep returning stale elapsed time."
  (clearEse)
  (ese :bdd-test t 100.0d0)
  (is (null (ese :bdd-test nil 101.0d0))))

(test ese-different-keys-do-not-share-state
  "GOAL: independent effect states (e.g. two different cells that could
each pulse) must not interfere with each other."
  (clearEse)
  (ese :bdd-key-a t 1.0d0)
  (ese :bdd-key-b t 2.0d0)
  (is (not (= (ese :bdd-key-a t 5.0d0) (ese :bdd-key-b t 5.0d0)))))
