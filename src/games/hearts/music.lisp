(in-package :edm-engine/games/hearts)

;;; Same classic-puzzle-game genre, third distinct progression —
;;; I-IV-V-I in D major (D-G-A-D), the simplest classic progression,
;;; distinct from Queens' C-major I-V-vi-IV and Wordle's G-major
;;; I-vi-IV-V.

(defparameter +hearts-theme-bass-notes+ '(-19 -14 -12 -19))

(defparameter +hearts-theme-melody-bars+
  '((5 9 12 9 10 9 7 5)     ; bar 1, over D:  D5 F#5 A5 F#5 G5 F#5 E5 D5
    (7 10 14 10 12 10 9 7)  ; bar 2, over G:  E5 G5 B5 G5 A5 G5 F#5 E5
    (9 12 17 12 14 12 10 9) ; bar 3, over A:  F#5 A5 D6 A5 B5 A5 G5 F#5
    (5 10 14 10 12 9 7 5))  ; bar 4, over D:  D5 G5 B5 G5 A5 F#5 E5 D5 (resolves to D5)
  "Diatonic D-major throughout.")

(defparameter +hearts-theme-comp-thirds+ '(9 14 16 9))

(declaim (ftype (function () list) hearts-theme-pattern))
(defun hearts-theme-pattern ()
  (loop for bar from 0 below 4
        append (loop for row-in-bar from 0 below 8
                     for melody-note = (nth row-in-bar (nth bar +hearts-theme-melody-bars+))
                     for bass-note = (nth bar +hearts-theme-bass-notes+)
                     for comp-note = (and (oddp row-in-bar) (nth bar +hearts-theme-comp-thirds+))
                     collect (list (cons melody-note :square)
                                   (cons bass-note :triangle)
                                   (and comp-note (cons comp-note :square))))))

(defparameter +hearts-theme-row-duration+ 0.2)
