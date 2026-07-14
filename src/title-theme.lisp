(in-package :edm-engine)

;;; The engine's own identity theme — distinct from every table's
;;; theme (I-V-vi-IV/I-vi-IV-V/I-IV-V-I/vi-IV-I-V have all been used;
;;; this is E major I-IV-V-I, the same "anthem" shape as Hearts'
;;; D-major but a fifth key, giving the title screen its own musical
;;; identity rather than reusing a table's theme).

(defparameter +title-theme-bass-notes+ '(-17 -12 -10 -17))

(defparameter +title-theme-melody-bars+
  '((7 11 14 11 12 11 9 7)    ; bar 1, over E:  E5 G#5 B5 G#5 A5 G#5 F#5 E5
    (9 12 18 12 14 12 11 9)   ; bar 2, over A:  F#5 A5 D#6 A5 B5 A5 G#5 F#5
    (11 14 18 14 16 14 12 11) ; bar 3, over B:  G#5 B5 D#6 B5 C#6 B5 A5 G#5
    (7 11 14 11 12 11 9 7))   ; bar 4, over E:  same as bar 1 — an AABA anthem shape
  "Diatonic E-major throughout.")

(defparameter +title-theme-comp-thirds+ '(11 16 18 11))

(declaim (ftype (function () list) title-theme-pattern))
(defun title-theme-pattern ()
  (loop for bar from 0 below 4
        append (loop for row-in-bar from 0 below 8
                     for melody-note = (nth row-in-bar (nth bar +title-theme-melody-bars+))
                     for bass-note = (nth bar +title-theme-bass-notes+)
                     for comp-note = (and (oddp row-in-bar) (nth bar +title-theme-comp-thirds+))
                     collect (list (cons melody-note :square)
                                   (cons bass-note :triangle)
                                   (and comp-note (cons comp-note :square))))))

(defparameter +title-theme-row-duration+ 0.2)
