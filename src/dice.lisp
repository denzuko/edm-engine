(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

;;; Generic polyhedral dice — extracted so a game needing dice doesn't
;;; reimplement "roll a die" per game the way Hearts and Queens once
;;; each had their own deck/shader code. Yahtzee specifically only
;;; ever uses :D6 (its own scoring rules are d6-specific by
;;; definition), but the primitive itself doesn't hardcode that.

(defparameter +die-sides+
  '((:d4 . 4) (:d6 . 6) (:d8 . 8) (:d10 . 10) (:d12 . 12) (:d20 . 20)))

(declaim (ftype (function (keyword fixnum) fixnum) roll-die))
(defun roll-die (die-type seed)
  (1+ (random (cdr (assoc die-type +die-sides+)) (sb-ext:seed-random-state seed))))

(declaim (ftype (function (keyword fixnum fixnum) list) roll-dice-n))
(defun roll-dice-n (die-type count seed)
  (let ((rng (sb-ext:seed-random-state seed))
        (sides (cdr (assoc die-type +die-sides+))))
    (loop repeat count collect (1+ (random sides rng)))))

(declaim (ftype (function (fixnum) fixnum) roll-percentile))
(defun roll-percentile (seed)
  "Two d10s combined per the standard percentile-die convention: a
tens-die (0/10/.../90) and a ones-die (0-9) summed; 00+0 conventionally
reads as 100, not 0."
  (let* ((rng (sb-ext:seed-random-state seed))
         (tens (* 10 (random 10 rng)))
         (ones (random 10 rng))
         (total (+ tens ones)))
    (if (zerop total) 100 total)))

;;; Roll animation — the "still tumbling" visual before dice settle on
;;; their real values. Not a TWEEN (which interpolates a continuous
;;; position); a die roll needs discrete flickering face values for a
;;; short window, then the real result.

(defstruct roll-animation
  (start-time 0.0d0 :type double-float)
  (duration 0.4d0 :type double-float)
  (final-values nil :type list))

(declaim (ftype (function (roll-animation double-float) boolean) roll-animation-finished-p))
(defun roll-animation-finished-p (anim now)
  (>= (- now (roll-animation-start-time anim)) (roll-animation-duration anim)))

(declaim (ftype (function (roll-animation double-float fixnum) list) roll-animation-display-values))
(defun roll-animation-display-values (anim now sides)
  "FINAL-VALUES once the animation's finished; otherwise a flicker of
plausible face values, one per final value, cheaply derived from NOW
so consecutive frames actually change (not a seeded RNG — this is
visual noise, not game state)."
  (if (roll-animation-finished-p anim now)
      (roll-animation-final-values anim)
      (loop for i from 0 below (length (roll-animation-final-values anim))
            collect (1+ (mod (+ (floor (* now 30)) (* i 7)) sides)))))
