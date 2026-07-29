(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; #32 — the recurring single/double-float time-comparison bug class,
;;; found three separate times by manual audit (AI-TIMER-RESET's
;;; delay field, ROLL-ANIMATION's duration field, TWEEN's own
;;; duration field, #31) — the same shape each time: a struct field
;;; typed SINGLE-FLOAT for a value compared against a DOUBLE-FLOAT
;;; time source (RAYLIB:GET-TIME). Per the issue's own stated
;;; priority ("the macro-level fix is the more valuable of the two"):
;;; DEFINE-TIMED-STRUCT wraps DEFSTRUCT, making the mistake impossible
;;; to write rather than merely detectable after the fact — a real
;;; macro-expansion-time check, not a runtime assertion.

(defmacro expands-without-error (form)
  `(handler-case (progn (macroexpand-1 ',form) t)
     (error () nil)))

(test define-timed-struct-expands-cleanly-when-every-time-slot-is-double-float
  (is-true (expands-without-error
            (define-timed-struct spec-good-timing (start-time duration)
              (start-x 0.0 :type single-float)
              (start-time 0.0d0 :type double-float)
              (duration 0.3d0 :type double-float)))))

(test define-timed-struct-signals-a-macro-expansion-time-error-for-a-single-float-time-slot
  "The actual bug class this exists to prevent — DURATION declared
SINGLE-FLOAT despite being named as a time slot."
  (signals error
    (macroexpand-1 '(define-timed-struct spec-bad-timing (duration)
                      (start-x 0.0 :type single-float)
                      (duration 0.3 :type single-float)))))

(test define-timed-struct-signals-an-error-for-a-time-slot-missing-a-type-declaration-entirely
  (signals error
    (macroexpand-1 '(define-timed-struct spec-missing-type (duration)
                      (duration 0.3)))))

(test define-timed-struct-produces-a-genuinely-usable-struct
  "Not just a validation shell — MACROEXPAND-1's own result, once
loaded, behaves exactly like the equivalent plain DEFSTRUCT would."
  (define-timed-struct spec-real-timing (start-time)
    (start-x 0.0 :type single-float)
    (start-time 0.0d0 :type double-float))
  (let ((s (make-spec-real-timing :start-x 1.0 :start-time 2.0d0)))
    (is (= 1.0 (spec-real-timing-start-x s)))
    (is (= 2.0d0 (spec-real-timing-start-time s)))))
