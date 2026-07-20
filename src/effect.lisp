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

;;; PARTICLE-EFFECT — a thin (ARENA . HANDLE) wrapper so a single
;;; arena-backed particle genuinely implements the generic EFFECT
;;; protocol (TWEEN.LISP), same as TWEEN does, per the design doc's
;;; own stated goal. Attempted directly rather than concluded not to
;;; fit without trying: an individual particle IS a single effect
;;; instance (tracked via its own arena handle); the arena itself (the
;;; pool of many) is a different thing from any one EFFECT instance
;;; within it, which is what this wraps — not a strained fit, once
;;; the actual unit of "one effect" is identified correctly.

(defstruct particle-effect
  (arena nil :type (or null arena))
  (handle nil))

(defmethod effect-finished-p ((effect particle-effect) now)
  (declare (ignore now))
  "\"Finished\" for a particle means genuinely despawned — the real
lifecycle event DESPAWNEXPIRED enforces on the arena, not a duration
tracked by this wrapper itself (unlike TWEEN's own duration-based
FINISHED-P)."
  (not (arena-alive-p (particle-effect-arena effect) (particle-effect-handle effect))))

(defmethod effect-apply ((effect particle-effect) now)
  (declare (ignore now))
  (arena-position (particle-effect-arena effect) (particle-effect-handle effect)))

;;; DEFEFFECT-STATE — the declarative macro layer this file's own
;;; earlier header comment named as explicit, real, separate remaining
;;; scope ("the macro/DSL syntax around this is real, separate, later
;;; scope — this is the primitive it would compile down to"), composing
;;; PULSEVAL/ESE rather than reimplementing them. Scoped to the :PULSE
;;; shape only, the one primitive that genuinely exists — #46's own
;;; taxonomy is itself an unimplemented catalog; validating against
;;; primitives that don't exist yet (:ZOOM, per the design doc's own
;;; sketch) would be speculative, not a real macro-time check.

(defmacro defeffect-state (name lambda-list shape)
  "Defines NAME as a function taking LAMBDA-LIST, whose body computes a
state-triggered effect value per SHAPE. SHAPE is currently
(:PULSE :KEY key-form :ACTIVE active-var :NOW now-var
 :RETURN (:ELAPSED | :VALUE) &KEY period base amplitude) — :ACTIVE/
:NOW name which of LAMBDA-LIST's parameters play those roles (matching
DEFLAYOUT's own :INDEX/:ROW-INDEX convention), so KEY-FORM can
reference other LAMBDA-LIST parameters too — Queens' actual retrofit
case needs CURSOR-ROW/CURSOR-COL in its key, not just ACTIVE/NOW.
:ELAPSED returns exactly what ESE itself returns for KEY (Queens'
actual, correct use case: a GPU shader computing its own sin() from
raw elapsed time), :VALUE composes that elapsed time through PULSEVAL
(a genuinely different consumer shape — CPU-side, wants the
oscillating value itself, not raw time) — two real cases, not the
same thing under two names."
  (destructuring-bind (kind &key key active now return period base amplitude) shape
    (ecase kind
      (:pulse
       (let ((ignorable-params (remove active (remove now lambda-list))))
         (ecase return
           (:elapsed
            `(defun ,name ,lambda-list
               ,@(when ignorable-params `((declare (ignorable ,@ignorable-params))))
               (ese ,key ,active ,now)))
           (:value
            `(defun ,name ,lambda-list
               ,@(when ignorable-params `((declare (ignorable ,@ignorable-params))))
               (let ((elapsed (ese ,key ,active ,now)))
                 (when elapsed
                   (pulseVal elapsed
                             ,@(when period `(:period ,period))
                             ,@(when base `(:base ,base))
                             ,@(when amplitude `(:amplitude ,amplitude)))))))))))))

;;; DEFEFFECT-SEQUENCE — the event-triggered counterpart to
;;; DEFEFFECT-STATE above, scoped to :CONFETTI, the one event-
;;; triggered primitive that genuinely exists (Yahtzee's win overlay,
;;; #34/#46). The full bus-event trigger mechanism the design doc
;;; sketches (:TRIGGER :EVENT :CARD-PLAYED) isn't built here — that's
;;; the VFX processor, real, separate, later scope per the design
;;; doc's own section on it, not conflated with this macro's actual
;;; job: composing which primitives chain together. The caller still
;;; decides *when* to invoke the generated function (a status-
;;; transition check, a bus-drain loop once that exists, whatever fits
;;; — this macro is agnostic to the trigger mechanism, matching how
;;; SPAWNCONFETTI itself was already agnostic to it).

(defmacro defeffect-sequence (name lambda-list shape)
  "Defines NAME as a function taking LAMBDA-LIST, whose body runs the
chained primitives in SHAPE. SHAPE is currently
(:CONFETTI :COUNT count-form :SPEED-RANGE range-form) — SPAWNCONFETTI's
own shape, composed here rather than reimplemented. LAMBDA-LIST is
expected to supply (arena origin-x origin-y now rng), SPAWNCONFETTI's
own required arguments, in that order — DEFEFFECT-SEQUENCE doesn't
invent a different calling convention for its one real consumer."
  (destructuring-bind (kind &key count speed-range) shape
    (ecase kind
      (:confetti
       (destructuring-bind (arena-var origin-x-var origin-y-var now-var rng-var) lambda-list
         `(defun ,name (,arena-var ,origin-x-var ,origin-y-var ,now-var ,rng-var)
            (spawnConfetti ,arena-var ,origin-x-var ,origin-y-var ,count ,now-var ,rng-var
                            :speed-range ,speed-range)))))))
