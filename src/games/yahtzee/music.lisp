(in-package :edm-engine/games/yahtzee)

;;; Same genre, fourth distinct progression — vi-IV-I-V in A major
;;; (F#m-D-A-E), the other half of the "four chords" pop cliche from
;;; Queens' I-V-vi-IV, distinct from Wordle's G-major and Hearts'
;;; D-major.

(defparameter +yahtzee-theme-bass-notes+ '(-15 -19 -12 -17))

(defparameter +yahtzee-theme-melody-bars+
  '((9 12 16 12 14 12 11 9)     ; bar 1, over F#m: F#5 A5 C#6 A5 B5 A5 G#5 F#5
    (10 14 17 14 16 14 12 10)   ; bar 2, over D:   G5 B5 D6 B5 C#6 B5 A5 G5
    (12 16 21 16 17 16 14 12)   ; bar 3, over A:   A5 C#6 F#6 C#6 D6 C#6 B5 A5
    (9 14 17 14 16 12 11 9))    ; bar 4, over E:   F#5 B5 D6 B5 C#6 A5 G#5 F#5 (resolves to F#5)
  "Diatonic A-major throughout.")

(defparameter +yahtzee-theme-comp-thirds+ '(12 9 16 11))

(declaim (ftype (function () list) yahtzee-theme-pattern))
(defun yahtzee-theme-pattern ()
  (loop for bar from 0 below 4
        append (loop for row-in-bar from 0 below 8
                     for melody-note = (nth row-in-bar (nth bar +yahtzee-theme-melody-bars+))
                     for bass-note = (nth bar +yahtzee-theme-bass-notes+)
                     for comp-note = (and (oddp row-in-bar) (nth bar +yahtzee-theme-comp-thirds+))
                     collect (list (cons melody-note :square)
                                   (cons bass-note :triangle)
                                   (and comp-note (cons comp-note :square))))))

(defparameter +yahtzee-theme-row-duration+ 0.2)
