(in-package :edm-engine/games/queens)

(declaim (optimize (speed 3) (safety 3)))

(defparameter +queens-level-count+ 25)

(declaim (ftype (function (fixnum) fixnum) queens-board-size-for-level))
(defun queens-board-size-for-level (level)
  "Standard progression: 4x4 through 8x8, five levels per size."
  (+ 4 (floor (1- level) 5)))

(declaim (ftype (function (fixnum) fixnum) queens-seed-for-level))
(defun queens-seed-for-level (level)
  "The level number itself — simplest possible reproducible seed, and
transparent: level 7 is always seed 7, nothing hidden."
  level)

(defstruct queens-board
  (size 0 :type fixnum)
  (regions nil :type (simple-array fixnum (*)))
  (placement nil :type list))

(declaim (ftype (function (queens-board fixnum fixnum) fixnum) region-at))
(defun region-at (board row col)
  (aref (queens-board-regions board) (+ (* row (queens-board-size board)) col)))

(defun shuffled-range (n seed salt)
  "0..N-1 in a deterministic order derived from SEED and SALT — different
SALT per call within one generation gives different (but reproducible)
orderings, e.g. one per board row."
  (let ((rng (sb-ext:seed-random-state (+ (* seed 1000003) salt)))
        (vec (coerce (loop for i below n collect i) 'vector)))
    (loop for i from (1- (length vec)) downto 1
          do (rotatef (aref vec i) (aref vec (random (1+ i) rng))))
    (coerce vec 'list)))

(defun place-row (row size seed placement)
  "Recursive helper for GENERATE-QUEEN-PLACEMENT. A real top-level DEFUN,
not LABELS — this package shadow-imports SCREAMER:DEFUN (via
SCREAMER:DEFINE-SCREAMER-PACKAGE), which is what actually threads the
nondeterministic continuation through recursive calls. A LABELS-defined
local function is invisible to that transform even when called from
inside a nondeterministic context, and fails with 'must be called only
from a nondeterministic context' on the second recursive call — the
first call still works because it's textually inside the ONE-VALUE form
directly."
  (if (>= row size)
      (reverse placement)
      (let ((col (a-member-of (shuffled-range size seed row))))
        (assert! (notv (memberv col placement)))
        (when placement
          (assert! (notv (=v (abs (- col (first placement))) 1))))
        (place-row (1+ row) size seed (cons col placement)))))

(declaim (ftype (function (fixnum fixnum) list) generate-queen-placement))
(defun generate-queen-placement (size seed)
  "One column per row (0-indexed) — A-MEMBER-OF tries candidates in the
order given, so pre-shuffling with a seeded RNG makes the first
solution SCREAMER finds deterministic per seed, not just 'a' valid
placement."
  (one-value (place-row 0 size seed nil)))

(defun cell-neighbors (size row col)
  (loop for (dr . dc) in '((-1 . 0) (1 . 0) (0 . -1) (0 . 1))
        for r = (+ row dr) for c = (+ col dc)
        when (and (<= 0 r) (< r size) (<= 0 c) (< c size))
          collect (cons r c)))

(defun generate-regions (size placement seed)
  "One region per queen, grown outward one cell at a time via seeded
random selection from the current frontier until every cell is
assigned — a real contiguous partition, not an arbitrary labeling."
  (let ((regions (make-array (* size size) :element-type 'fixnum :initial-element -1))
        (frontier nil)
        (rng (sb-ext:seed-random-state (+ (* seed 1000003) 999))))
    (flet ((idx (r c) (+ (* r size) c)))
      (loop for region-id from 0
            for col in placement
            for row from 0
            do (setf (aref regions (idx row col)) region-id)
               (dolist (n (cell-neighbors size row col))
                 (push (cons region-id n) frontier)))
      (loop while frontier
            do (let* ((i (random (length frontier) rng))
                      (entry (nth i frontier)))
                 (setf frontier (nconc (subseq frontier 0 i) (subseq frontier (1+ i))))
                 (let ((region-id (car entry)) (r (cadr entry)) (c (cddr entry)))
                   (when (= -1 (aref regions (idx r c)))
                     (setf (aref regions (idx r c)) region-id)
                     (dolist (n (cell-neighbors size r c))
                       (when (= -1 (aref regions (idx (car n) (cdr n))))
                         (push (cons region-id n) frontier))))))))
    regions))

(declaim (ftype (function (fixnum fixnum) queens-board) generate-board))
(defun generate-board (size seed)
  (let ((placement (generate-queen-placement size seed)))
    (make-queens-board :size size
                        :regions (generate-regions size placement seed)
                        :placement placement)))
