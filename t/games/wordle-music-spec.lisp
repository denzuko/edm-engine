(in-package :edm-engine/games/wordle/tests)
(in-suite :edm-engine-wordle)

(test wordle-theme-is-a-32-row-pattern
  (is (= 32 (length (wordle-theme-pattern)))))

(test wordle-theme-bass-follows-a-I-vi-IV-V-progression
  "G3 E3 C3 D3 — the doo-wop progression, distinct from Queens' C-major
I-V-vi-IV so the two tables don't sound identical."
  (let ((pattern (wordle-theme-pattern)))
    (is (equal '(-14 -17 -21 -19)
               (loop for bar from 0 below 4
                     collect (car (second (nth (* bar 8) pattern))))))))

(test wordle-theme-bass-holds-one-root-per-bar
  (let ((pattern (wordle-theme-pattern)))
    (dotimes (bar 4)
      (let ((bass-notes-this-bar
              (remove-duplicates
               (loop for row-in-bar from 0 below 8
                     collect (car (second (nth (+ (* bar 8) row-in-bar) pattern)))))))
        (is (= 1 (length bass-notes-this-bar)))))))

(test wordle-theme-melody-resolves-back-to-its-starting-note
  (let ((pattern (wordle-theme-pattern)))
    (is (= (car (first (first pattern))) (car (first (car (last pattern))))))))
