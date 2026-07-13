(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

;;; A real layout system, not per-screen hand arithmetic. The bug that
;;; prompted this: the difficulty-selection screen's description text
;;; had no wrapping at all and overflowed one card's boundary straight
;;; into the next card's space. Two genuinely reusable pieces: evenly
;;; spacing N fixed-size items in a container (already being hand-
;;; computed per screen — Hearts' hand layout, the difficulty cards,
;;; the tables list), and word-wrapping text to a width budget instead
;;; of letting it run off the edge of whatever it's drawn in.

(declaim (ftype (function (fixnum fixnum fixnum fixnum) list) centered-row-positions))
(defun centered-row-positions (n item-size gap total-size)
  "N evenly-spaced ITEM-SIZE items with GAP between them, centered
within TOTAL-SIZE — the starting position of each item, left to right."
  (when (plusp n)
    (let* ((content-size (+ (* n item-size) (* (1- n) gap)))
           (start (round (/ (- total-size content-size) 2.0))))
      (loop for i from 0 below n collect (+ start (* i (+ item-size gap)))))))

(declaim (ftype (function (string (function (string) fixnum) fixnum) list) wrap-text-lines))
(defun wrap-text-lines (text measure-fn max-width)
  "Greedy word-wrap TEXT into lines that fit MAX-WIDTH per MEASURE-FN
(a function from a string to its measured width — pixels via real
glyph metrics in the render layer, or plain character count in tests).
A single word wider than MAX-WIDTH still gets its own line whole,
never split mid-word."
  (let ((words (remove "" (uiop:split-string text :separator " ") :test #'string=)))
    (when words
      (let ((lines nil) (current nil))
        (dolist (word words)
          (let ((candidate (if current (format nil "~A ~A" current word) word)))
            (if (or (null current) (<= (funcall measure-fn candidate) max-width))
                (setf current candidate)
                (progn (push current lines) (setf current word)))))
        (when current (push current lines))
        (nreverse lines)))))
