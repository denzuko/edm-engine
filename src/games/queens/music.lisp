(in-package :edm-engine/games/queens)

;;; A classic-puzzle-game theme: light, playful, major-key (per the
;;; genre direction confirmed for this game) — I-V-vi-IV in C major
;;; (C-G-Am-F), the same familiar pop progression underlying a huge
;;; swath of upbeat major-key music, not an arbitrary chord sequence.
;;; Four bars, eight eighth-note rows each. The melody is sequenced —
;;; the same rising-then-falling shape repeated a step higher over each
;;; new chord — a real compositional device, not a random walk, and it
;;; resolves back to its opening note so the loop seams cleanly.

(defparameter +queens-theme-bass-notes+ '(-21 -14 -12 -16)
  "C3 G3 A3 F3 — the I-V-vi-IV progression's roots, one held per bar.")

(defparameter +queens-theme-melody-bars+
  '((3 7 10 7 8 7 5 3)      ; bar 1, over C:  C5 E5 G5 E5 F5 E5 D5 C5
    (5 8 12 8 10 8 7 5)     ; bar 2, over G:  D5 F5 A5 F5 G5 F5 E5 D5
    (7 10 15 10 12 10 8 7)  ; bar 3, over Am: E5 G5 C6 G5 A5 G5 F5 E5
    (3 8 12 8 10 7 5 3))    ; bar 4, over F:  C5 F5 A5 F5 G5 E5 D5 C5 (resolves to C5)
  "Diatonic C-major throughout — plays cleanly over all four chords of
a I-V-vi-IV progression, standard pop-melody practice.")

(defparameter +queens-theme-comp-thirds+ '(7 14 15 12)
  "E5 B5 C6 A5 — each chord's third, stabbed on the offbeat eighth-notes
for the bouncy, syncopated pulse a puzzle-game loop wants.")

(declaim (ftype (function () list) queens-theme-pattern))
(defun queens-theme-pattern ()
  "Builds the full 32-row tracker pattern: melody (square, lead), bass
(triangle, sustained per bar), and an offbeat comp stab (square,
rests on the downbeat)."
  (loop for bar from 0 below 4
        append (loop for row-in-bar from 0 below 8
                     for melody-note = (nth row-in-bar (nth bar +queens-theme-melody-bars+))
                     for bass-note = (nth bar +queens-theme-bass-notes+)
                     for comp-note = (and (oddp row-in-bar) (nth bar +queens-theme-comp-thirds+))
                     collect (list (cons melody-note :square)
                                   (cons bass-note :triangle)
                                   (and comp-note (cons comp-note :square))))))

(defparameter +queens-theme-row-duration+ 0.2
  "Eighth-note = 0.2s -> quarter-note = 0.4s -> 150 BPM: energetic
without being frantic, a Tetris-like puzzle-game tempo.")
