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

;; #36's first real retrofit — grounded against Queens, which had the
;; richest duplication (the grid origin math AND two of the three
;; found CENTER-WITHIN instances). Both primitives match the design
;; doc's own sketch exactly, not reinvented at implementation time.

(declaim (ftype (function (fixnum fixnum fixnum fixnum fixnum fixnum fixnum fixnum)
                          (values list list))
                centered-grid-positions))
(defun centered-grid-positions (rows cols item-w item-h gap-x gap-y container-w container-h)
  "Returns (values row-origins col-origins) — the same centering math
CENTERED-ROW-POSITIONS already does, per axis, composed rather than
reimplemented. ROW-ORIGINS has ROWS entries (each row's Y), COL-ORIGINS
has COLS entries (each column's X) — a cell at (ROW, COL) sits at
(NTH COL COL-ORIGINS), (NTH ROW ROW-ORIGINS)."
  (values (centered-row-positions rows item-h gap-y container-h)
          (centered-row-positions cols item-w gap-x container-w)))

(declaim (ftype (function (fixnum fixnum fixnum fixnum fixnum fixnum) (values fixnum fixnum))
                center-within))
(defun center-within (container-x container-y container-w container-h content-w content-h)
  "Top-left position to center a CONTENT-W x CONTENT-H element within a
CONTAINER-W x CONTAINER-H region at CONTAINER-X,CONTAINER-Y — the
formula that appeared three separate, byte-for-byte-identical times
across Queens' mark label, Queens' queen glyph, and Wordle's letter
tile before this retrofit, named once."
  (values (round (+ container-x (/ (- container-w content-w) 2.0)))
          (round (+ container-y (/ (- container-h content-h) 2.0)))))

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
