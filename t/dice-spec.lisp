(in-package :edm-engine/tests)
(in-suite :edm-engine)

(test roll-die-respects-side-count
  (dotimes (i 20)
    (is (<= 1 (roll-die :d4 i) 4)))
  (dotimes (i 20)
    (is (<= 1 (roll-die :d20 i) 20))))

(test roll-die-is-deterministic-per-seed
  (is (= (roll-die :d6 42) (roll-die :d6 42))))

(test roll-dice-n-gives-the-right-count-and-range
  (let ((rolls (roll-dice-n :d8 5 1)))
    (is (= 5 (length rolls)))
    (is (every (lambda (v) (<= 1 v 8)) rolls))))

(test roll-percentile-is-1-to-100
  (dotimes (i 30)
    (is (<= 1 (roll-percentile i) 100))))

(test roll-percentile-is-deterministic-per-seed
  (is (= (roll-percentile 7) (roll-percentile 7))))

;;; Roll animation — the visual "still tumbling" state before settling
;;; on the real rolled values.

(test make-roll-animation-not-finished-before-duration-elapses
  (let ((anim (make-roll-animation :start-time 10.0d0 :duration 0.4d0 :final-values '(3 5))))
    (is (not (roll-animation-finished-p anim 10.2d0)))))

(test roll-animation-finished-once-duration-elapses
  (let ((anim (make-roll-animation :start-time 10.0d0 :duration 0.4d0 :final-values '(3 5))))
    (is (roll-animation-finished-p anim 10.4d0))
    (is (roll-animation-finished-p anim 11.0d0))))

(test roll-animation-display-values-is-final-values-once-finished
  (let ((anim (make-roll-animation :start-time 10.0d0 :duration 0.4d0 :final-values '(3 5 6))))
    (is (equal '(3 5 6) (roll-animation-display-values anim 20.0d0 6)))))

(test roll-animation-display-values-is-still-the-right-length-mid-animation
  (let ((anim (make-roll-animation :start-time 10.0d0 :duration 0.4d0 :final-values '(3 5 6))))
    (is (= 3 (length (roll-animation-display-values anim 10.1d0 6))))))
