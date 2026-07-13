(in-package :edm-engine/games/wordle)

;;; Same genre as Queens' theme (classic-puzzle-game, light/major-key)
;;; but a distinct progression and melody so the two tables don't sound
;;; interchangeable — I-vi-IV-V in G major (G-Em-C-D), the doo-wop
;;; progression, a different familiar major-key pattern from Queens'
;;; C-major I-V-vi-IV.

(defparameter +wordle-theme-bass-notes+ '(-14 -17 -21 -19)
  "G3 E3 C3 D3 — the I-vi-IV-V progression's roots, one held per bar.")

(defparameter +wordle-theme-melody-bars+
  '((-2 2 5 2 3 2 0 -2)   ; bar 1, over G:  G4 B4 D5 B4 C5 B4 A4 G4
    (0 3 7 3 5 3 2 0)     ; bar 2, over Em: A4 C5 E5 C5 D5 C5 B4 A4
    (2 5 10 5 7 5 3 2)    ; bar 3, over C:  B4 D5 G5 D5 E5 D5 C5 B4
    (-2 3 7 3 5 2 0 -2))  ; bar 4, over D:  G4 C5 E5 C5 D5 B4 A4 G4 (resolves to G4)
  "Diatonic G-major throughout, same sequenced rising-falling shape
device Queens' melody uses, a step higher over each new chord.")

(defparameter +wordle-theme-comp-thirds+ '(2 -2 7 9)
  "B4 G4 E5 F#5 — each chord's third, offbeat stabs for the same
bouncy pulse Queens' comp channel uses.")

(declaim (ftype (function () list) wordle-theme-pattern))
(defun wordle-theme-pattern ()
  (loop for bar from 0 below 4
        append (loop for row-in-bar from 0 below 8
                     for melody-note = (nth row-in-bar (nth bar +wordle-theme-melody-bars+))
                     for bass-note = (nth bar +wordle-theme-bass-notes+)
                     for comp-note = (and (oddp row-in-bar) (nth bar +wordle-theme-comp-thirds+))
                     collect (list (cons melody-note :square)
                                   (cons bass-note :triangle)
                                   (and comp-note (cons comp-note :square))))))

(defparameter +wordle-theme-row-duration+ 0.2)
