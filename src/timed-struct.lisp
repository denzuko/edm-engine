(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

;;; #32 — the recurring single/double-float time-comparison bug class,
;;; found three separate times by manual audit this session
;;; (AI-TIMER-RESET's own delay field, ROLL-ANIMATION's own duration
;;; field, TWEEN's own duration field, #31) — the same shape each
;;; time: a struct field typed SINGLE-FLOAT for a value compared
;;; against a DOUBLE-FLOAT time source (RAYLIB:GET-TIME). Widening
;;; single to double doesn't gain precision, so boundary comparisons
;;; silently fail. Three instances found by three separate rounds of
;;; manual audit is not a sustainable detection method.
;;;
;;; Per the issue's own stated priority ("the macro-level fix is the
;;; more valuable of the two, worth prioritizing if only one gets
;;; built"): DEFINE-TIMED-STRUCT wraps DEFSTRUCT, checking at macro-
;;; expansion time — before compile, before runtime — that every slot
;;; named in TIME-SLOTS is declared :TYPE DOUBLE-FLOAT. A slot
;;; declared SINGLE-FLOAT, or with no :TYPE at all, is a macro-
;;; expansion-time error: the mistake becomes impossible to write,
;;; not merely detectable after the fact. Everything else about the
;;; resulting struct is identical to what a plain DEFSTRUCT would
;;; produce — no runtime cost, no behavior change beyond the compile-
;;; time check itself.

(defmacro define-timed-struct (name time-slots &body slots)
  "Like DEFSTRUCT, but every slot name in TIME-SLOTS must appear
among SLOTS with an explicit :TYPE DOUBLE-FLOAT declaration — a
macro-expansion-time error otherwise, naming which slot and what its
own declared type actually was (or that it had none)."
  (dolist (time-slot time-slots)
    (let ((slot-form (find time-slot slots
                            :key (lambda (s) (if (consp s) (first s) s)))))
      (unless slot-form
        (error "DEFINE-TIMED-STRUCT ~A: TIME-SLOTS names ~A, but no such slot exists"
               name time-slot))
      (let ((declared-type (and (consp slot-form) (getf (cddr slot-form) :type))))
        (unless (equal declared-type 'double-float)
          (error "DEFINE-TIMED-STRUCT ~A: time slot ~A must be declared :TYPE DOUBLE-FLOAT, ~
                  not ~A — SINGLE-FLOAT time values silently fail boundary comparisons ~
                  against RAYLIB:GET-TIME's own DOUBLE-FLOAT (#32)."
                 name time-slot (or declared-type "no :TYPE at all"))))))
  `(defstruct ,name ,@slots))
