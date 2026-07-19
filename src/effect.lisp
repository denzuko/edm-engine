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
