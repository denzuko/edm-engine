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

;; #46's confetti/particle work — the arena's first real adoption per
;; #33 (correctly designed, never adopted). Grounded in Yahtzee's win
;; overlay (#34, now fixed), #46's own named consumer. BDD, per
;; docs/test-layer-separation.md — written before SPAWNCONFETTI/
;; DESPAWNEXPIRED exist.

(test spawn-confetti-populates-the-arena-with-live-particles
  "GOAL: a win should produce a visible burst of particles, not
nothing and not an error."
  (let ((arena (make-arena 50)))
    (spawnConfetti arena 0.0 0.0 20 0.0d0 (make-random-state t))
    (is (= 20 (length (arena-live-handles arena))))))

(test spawn-confetti-never-exceeds-arena-capacity
  "GOAL: requesting more particles than the arena can hold should
gracefully spawn as many as fit, never signal an error that could
take down the whole session (#23's own standing discipline, extended
here to a new subsystem)."
  (let ((arena (make-arena 5)))
    (spawnConfetti arena 0.0 0.0 20 0.0d0 (make-random-state t))
    (is (= 5 (length (arena-live-handles arena))))))

(test despawn-expired-removes-old-particles-but-not-fresh-ones
  "GOAL: particles should disappear after they've lived their expected
lifetime, not linger forever or vanish immediately."
  (let ((arena (make-arena 10)))
    (spawnConfetti arena 0.0 0.0 5 0.0d0 (make-random-state t))
    (despawnExpired arena 10.0d0 2.0d0)
    (is (= 0 (length (arena-live-handles arena))))))

;;; PARTICLE-EFFECT — a thin wrapper struct (ARENA . HANDLE) so a
;;; single arena-backed particle genuinely implements the generic
;;; EFFECT protocol (EFFECT-FINISHED-P/EFFECT-APPLY), same as TWEEN
;;; does, per the design doc's own stated goal ('card-flip tweens,
;;; camera shake, and particle bursts all implement this'). Attempted
;;; directly rather than concluded not to fit without trying — a real,
;;; individual particle genuinely is a single effect instance, tracked
;;; via its own arena handle; the arena itself (a pool of many) is a
;;; different thing from any one EFFECT instance within it, which is
;;; what this wraps.

(test particle-effect-finished-p-is-true-once-the-handle-is-despawned
  "GOAL: 'finished' for a particle means genuinely despawned (no longer
alive in its arena), the actual, real lifecycle event — not a
duration-based guess the way TWEEN's own finished-p works, since a
particle's lifetime is enforced by DESPAWNEXPIRED acting on the arena,
not tracked by the wrapper itself."
  (let* ((arena (make-arena 10))
         (handles (spawnConfetti arena 0.0 0.0 1 0.0d0 (make-random-state t)))
         (pe (make-particle-effect :arena arena :handle (first handles))))
    (is (not (effect-finished-p pe 0.0d0)))
    (despawnExpired arena 10.0d0 2.0d0)
    (is (effect-finished-p pe 10.0d0))))

(test particle-effect-apply-matches-arena-position-directly
  "Same composition principle as TWEEN's own EFFECT-APPLY method — this
returns exactly what ARENA-POSITION itself would for the wrapped
handle, not a reimplementation of position lookup."
  (let* ((arena (make-arena 10))
         (handles (spawnConfetti arena 5.0 7.0 1 0.0d0 (make-random-state t)))
         (pe (make-particle-effect :arena arena :handle (first handles))))
    (multiple-value-bind (ex ey) (effect-apply pe 0.0d0)
      (multiple-value-bind (ax ay) (arena-position arena (first handles))
        (is (= ex ax))
        (is (= ey ay))))))

;;; DEFEFFECT-STATE — #37's own explicitly-named remaining scope
;;; ("the macro/DSL syntax around this is real, separate, later
;;; scope" — effect.lisp's own header comment), the declarative layer
;;; composing PULSEVAL/ESE rather than reimplementing them. BDD-first,
;;; written before DEFEFFECT-STATE exists.

(test defeffect-state-pulse-elapsed-matches-ese-directly
  "GOAL: the :RETURN :ELAPSED variant must return exactly what ESE
itself would for the same key — Queens' actual, correct use case (a
GPU shader computing its own sin() from raw elapsed time, not a
CPU-computed pulse value), not forcing every consumer through
PULSEVAL just to prove the macro composes something."
  (clearEse)
  (defeffect-state test-cursor-pulse (active-p now)
    (:pulse :key :test-cursor-key :active active-p :now now :return :elapsed))
  (is (= (ese :test-cursor-key t 5.0d0) (test-cursor-pulse t 5.0d0))))

(test defeffect-state-pulse-value-matches-pulseval-of-the-elapsed-time
  "GOAL: the :RETURN :VALUE variant composes ESE's elapsed time through
PULSEVAL — a genuinely different consumer shape (CPU-side, wants the
oscillating value itself) from the :ELAPSED case above, not the same
thing under a different name."
  (clearEse)
  (defeffect-state test-cpu-pulse (active-p now)
    (:pulse :key :test-cpu-key :active active-p :now now :return :value
            :period 1.0d0 :base 0.5 :amplitude 0.5))
  (let ((elapsed (ese :test-cpu-key t 3.0d0)))
    (clearEse)
    (is (= (pulseVal elapsed :period 1.0d0 :base 0.5 :amplitude 0.5)
           (test-cpu-pulse t 3.0d0)))))

(test defeffect-state-pulse-returns-nil-when-inactive
  "GOAL: inactive state means no pulse at all, matching ESE's own NIL-
when-inactive contract directly, not a special zero/false value the
caller has to know to check for separately."
  (clearEse)
  (defeffect-state test-inactive-pulse (active-p now)
    (:pulse :key :test-inactive-key :active active-p :now now :return :elapsed))
  (is (null (test-inactive-pulse nil 1.0d0))))

(test defeffect-state-key-can-reference-other-lambda-list-parameters
  "GOAL: Queens' actual retrofit case — the key needs CURSOR-ROW/
CURSOR-COL, parameters beyond just ACTIVE/NOW — checked directly, not
assumed possible from the simpler cases above alone."
  (clearEse)
  (defeffect-state test-cell-pulse (row col active-p now)
    (:pulse :key (list :test-cell row col) :active active-p :now now :return :elapsed))
  (is (= (ese (list :test-cell 2 3) t 5.0d0) (test-cell-pulse 2 3 t 5.0d0))))

;;; DEFEFFECT-SEQUENCE — the event-triggered counterpart to
;;; DEFEFFECT-STATE above, scoped to :CONFETTI, the one event-
;;; triggered primitive that genuinely exists (Yahtzee's win overlay).
;;; The full bus-event trigger mechanism (:TRIGGER :EVENT :CARD-PLAYED,
;;; per the design doc's own sketch) isn't built — that's the VFX
;;; processor, real, separate, later scope, same as #37's own doc
;;; names it. This composes SPAWNCONFETTI as a callable sequence; the
;;; caller still decides *when* to invoke it (Yahtzee's own status-
;;; transition check), matching the doc's own distinction that the
;;; macro's job is "which primitives chain together," not "when to
;;; fire."

(test defeffect-sequence-confetti-spawns-exactly-the-declared-count
  "GOAL: the generated function spawns particles matching SPAWNCONFETTI
directly — the macro composes the primitive, it doesn't reimplement
spawning logic of its own."
  (defeffect-sequence test-confetti-burst (arena origin-x origin-y now rng)
    (:confetti :count 30 :speed-range 150.0))
  (let ((arena (make-arena 50)))
    (test-confetti-burst arena 0.0 0.0 0.0d0 (make-random-state t))
    (is (= 30 (length (arena-live-handles arena))))))
