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

(declaim (ftype (function (fixnum fixnum fixnum fixnum) fixnum) lrp))
(defun lrp (base-offset index item-size gap)
  "LRP = linear row position. BASE-OFFSET + INDEX * (ITEM-SIZE + GAP) —
a fixed-start row, the non-centered sibling of CENTERED-ROW-POSITIONS.
#36's second real gap named in the design doc, retrofitted against
Hearts' HAND-CARD-X and Yahtzee's dice-row positioning, both of which
independently duplicate this exact shape. Named per the project's
token-golfed naming convention (docs/naming-convention.md) — called
every frame per hand/dice-row item, a genuinely hot, frequently-
repeated call site."
  (+ base-offset (* index (+ item-size gap))))

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

;; #36's own open question resolved: yes, general — Hearts' three
;; AI-opponent positions (a fixed offset from one edge, centered on
;; the perpendicular axis) is a real, reusable shape, not something
;; that stays hand-rolled just because Hearts is currently its only
;; consumer. Single-float throughout — this shape's actual consumer
;; needs raylib-coordinate precision, not fixnum pixel-grid math like
;; CENTERED-ROW-POSITIONS/LRP/CENTER-WITHIN above.
(declaim (ftype (function ((member :left :right :top :bottom)
                            single-float single-float single-float single-float single-float)
                          (values single-float single-float))
                anchor-at-edge))
(defun anchor-at-edge (edge offset container-w container-h content-w content-h)
  "A CONTENT-W x CONTENT-H element positioned OFFSET from EDGE of a
CONTAINER-W x CONTAINER-H container, centered on the perpendicular
axis — the shape Hearts' three AI-opponent card-stack origins share,
found duplicated three separate times before this retrofit."
  (ecase edge
    (:left (values offset (/ (- container-h content-h) 2.0)))
    (:right (values (- container-w offset) (/ (- container-h content-h) 2.0)))
    (:top (values (/ (- container-w content-w) 2.0) offset))
    (:bottom (values (/ (- container-w content-w) 2.0) (- container-h offset)))))

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

;;; unifiedspec's spacing/radius scale (moved from render.lisp, #36) —
;;; pure integer/float data, no raylib dependency, needed here at
;;; macro-expansion time by DEFLAYOUT below.

(defparameter +space-1+ 4) (defparameter +space-2+ 8) (defparameter +space-3+ 12)
(defparameter +space-4+ 16) (defparameter +space-5+ 24) (defparameter +space-6+ 32)
(defparameter +space-7+ 48) (defparameter +space-8+ 64)
(defparameter +radius-sm+ 0.03) (defparameter +radius-md+ 0.06) (defparameter +radius-lg+ 0.1)

;;; DEFLAYOUT — #36's own remaining, central scope: declaring a
;;; screen's layout as data, composing the primitives above (starting
;;; with the :ROW/LRP shape, Hearts' HAND-CARD-X's actual retrofit
;;; case; other shapes are real, separate follow-on scope, not
;;; attempted in this first version, matching the design doc's own
;;; "library first, proven against one real consumer" discipline).

(defparameter +space-scale-symbols+ '(+space-1+ +space-2+ +space-3+ +space-4+
                                       +space-5+ +space-6+ +space-7+ +space-8+)
  "The symbols DEFLAYOUT's :GAP enforcement checks against — the design
doc's own stated rule: a bare pixel literal in :GAP position should be
a compile error, not a style nit caught in review. Checked as symbol
names at macro-expansion time (before GAP's value even exists), not a
runtime type check against the resolved integer, which couldn't tell
a real +SPACE-N+ reference apart from a bare literal that happens to
equal the same number.")

(defmacro deflayout (name lambda-list shape)
  "Defines NAME as a function taking LAMBDA-LIST, whose body computes a
position per SHAPE. SHAPE is currently (:ROW :ANCHOR anchor-form
:ITEM-SIZE size-form :GAP gap-form :INDEX index-var) — LRP's own
shape, composed here rather than reimplemented. :GAP must be the
literal 0 (the absence of spacing, not a spacing value, exempted from
the scale check for exactly that reason) or one of the +SPACE-N+
symbols above — a bare non-zero literal like 55 is a real
macro-expansion-time error, not a runtime one."
  (destructuring-bind (kind &key anchor item-size gap index) shape
    (ecase kind
      (:row
       (unless (or (eql gap 0) (member gap +space-scale-symbols+))
         (error "DEFLAYOUT ~A: :GAP must be 0 or one of ~A, got ~S (a bare non-zero literal is not a spacing scale reference)"
                name +space-scale-symbols+ gap))
       (let ((ignorable-params (remove index lambda-list)))
         `(defun ,name ,lambda-list
            ,@(when ignorable-params `((declare (ignorable ,@ignorable-params))))
            (lrp ,anchor ,index ,item-size ,gap)))))))
