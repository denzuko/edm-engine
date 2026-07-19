(in-package :edm-engine)

;;; #37's DEFEFFECT-STATE, pure core first — the state-triggered
;;; (persistent, enter/exit) effect lifecycle the design doc names
;;; explicitly, generalized from Queens' already-proven cell shader
;;; pulse (0.5 + 0.5*sin(time*6.0)) rather than invented from scratch.
;;; The macro/DSL syntax around this is real, separate, later scope —
;;; this is the primitive it would compile down to, proven on its own
;;; first, same discipline as #37's stylesheet DSL build order.
;;;
;;; Named per docs/naming-convention.md.

(declaim (ftype (function (double-float &key (:period double-float) (:base single-float) (:amplitude single-float))
                          single-float)
                pulseVal))
(defun pulseVal (elapsed &key (period 1.0d0) (base 0.5) (amplitude 0.5))
  "Generalizes Queens' cell shader's own pulse formula (verified
against it directly in the spec, not just resembling it): a 0..1
sine oscillation, PERIOD seconds per cycle, scaled by BASE/AMPLITUDE
so callers don't each re-derive the (0.7 + 0.3*pulse)-style scaling
Queens' shader does inline."
  (float (+ base (* amplitude (+ 0.5d0 (* 0.5d0 (sin (/ (* 2.0d0 pi elapsed) period))))))
         1.0))

(defvar *ese* (make-hash-table :test #'equal)
  "key -> entry-time (double-float, when this key's state most
recently became active), or absent if not currently active.")

(declaim (ftype (function (t boolean double-float) (or null double-float)) ese))
(defun ese (key active-p now)
  "ese = effect state elapsed. The actual point of generalizing away
from Queens' global TIME uniform: returns seconds elapsed since KEY's
state *most recently became* active, not wall-clock time since the
program started — a pulse should start fresh when a cell is newly
selected, not be phase-locked to however long the process has been
running. Returns NIL when ACTIVE-P is false, and clears the entry so
a later re-activation starts a genuinely fresh pulse, not a resumed
one. Called every frame per potentially-pulsing element, hence the
acronym per the naming convention's own stated bar — measured
directly (tiktoken/o200k_base) against a spelled-out alternative
before choosing it, not guessed."
  (if active-p
      (progn
        (unless (gethash key *ese*)
          (setf (gethash key *ese*) now))
        (- now (gethash key *ese*)))
      (progn
        (remhash key *ese*)
        nil)))

(defun clearEse ()
  "Test isolation, same rationale as CLEARMETRICS — not a production
feature. Full camelCase, not acronym-tier: called rarely (test setup
only), not the per-frame hot path ESE itself is."
  (clrhash *ese*))

;;; #46's confetti/particle work — the arena's (#33) first real
;;; adoption, grounded in Yahtzee's win overlay (#34, now fixed),
;;; #46's own named consumer. Genuinely needs the arena's "many
;;; simultaneous entities" design, unlike a single card tween — the
;;; actual reason this is the arena's first real consumer rather than
;;; forcing a smaller-cardinality effect into it.

(declaim (ftype (function (arena single-float single-float fixnum double-float random-state
                           &key (:speed-range single-float))
                          list)
                spawnConfetti))
(defun spawnConfetti (arena origin-x origin-y count now rng &key (speed-range 100.0))
  "Spawns up to COUNT particles at (ORIGIN-X, ORIGIN-Y), random
velocity within +/- SPEED-RANGE on each axis, recording NOW as each
one's spawn-time. Returns the actually-spawned handles — fewer than
COUNT, gracefully, if the arena's capacity is exhausted first, never
signals an error that could take down the whole session (#23's
standing discipline, extended to a new subsystem). RNG is an explicit
random-state, not the global *RANDOM-STATE* — reproducible per #47's
own standing rule on seeded randomness, the same discipline Queens'
board generation and the card shuffle already correctly use."
  (loop repeat count
        for h = (handler-case (arena-spawn arena) (error () nil))
        while h
        collect (progn
                  (arena-set-position arena h origin-x origin-y)
                  (arena-set-velocity arena h
                                       (- (random (* 2.0 speed-range) rng) speed-range)
                                       (- (random (* 2.0 speed-range) rng) speed-range))
                  (arena-set-spawn-time arena h (float now 1.0))
                  h)))

(declaim (ftype (function (arena double-float double-float) fixnum) despawnExpired))
(defun despawnExpired (arena now max-age)
  "Despawns every live particle older than MAX-AGE seconds. Returns
the count despawned."
  (let ((count 0))
    (dolist (h (arena-live-handles arena))
      (when (> (- now (float (arena-spawn-time arena h) 1.0d0)) max-age)
        (arena-despawn arena h)
        (incf count)))
    count))
