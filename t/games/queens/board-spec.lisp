(in-package :edm-engine/games/queens/tests)
(in-suite :edm-engine-queens)

;;; Level progression

(test queens-level-count-is-25
  (is (= 25 edm-engine/games/queens:+queens-level-count+)))

(test board-size-grows-with-level-standard-progression
  "4x4 through 8x8, five levels per size."
  (is (= 4 (queens-board-size-for-level 1)))
  (is (= 4 (queens-board-size-for-level 5)))
  (is (= 5 (queens-board-size-for-level 6)))
  (is (= 5 (queens-board-size-for-level 10)))
  (is (= 6 (queens-board-size-for-level 11)))
  (is (= 8 (queens-board-size-for-level 25))))

(test seed-is-attached-per-level-and-deterministic
  (is (= (queens-seed-for-level 7) (queens-seed-for-level 7)))
  (is (/= (queens-seed-for-level 7) (queens-seed-for-level 8))))

;;; Board generation — screamer-based placement + seeded region growth

(test generate-board-produces-one-queen-per-row-and-column
  (let* ((board (generate-board 5 42))
         (placement (queens-board-placement board)))
    (is (= 5 (length placement)))
    (is (= 5 (length (remove-duplicates placement))) "columns must be unique")))

(test generate-queens-board-placement-has-no-adjacent-rows-touching
  (let* ((board (generate-board 6 99))
         (placement (queens-board-placement board)))
    (loop for (c1 c2) on placement
          while c2
          do (is (> (abs (- c1 c2)) 1)))))

(test generate-board-is-deterministic-for-the-same-seed
  (let ((a (generate-board 5 7))
        (b (generate-board 5 7)))
    (is (equal (queens-board-placement a) (queens-board-placement b)))
    (is (equalp (queens-board-regions a) (queens-board-regions b)))))

(test generate-board-differs-for-different-seeds
  (let ((a (generate-board 6 1))
        (b (generate-board 6 2)))
    (is (not (and (equal (queens-board-placement a) (queens-board-placement b))
                  (equalp (queens-board-regions a) (queens-board-regions b)))))))

(test generate-queens-board-regions-cover-every-cell-exactly-once
  (let* ((size 6)
         (board (generate-board size 3))
         (regions (queens-board-regions board)))
    (is (= (* size size) (length regions)))
    (is (every (lambda (r) (<= 0 r (1- size))) regions))))

(test generate-board-each-queens-cell-belongs-to-its-own-region
  (let* ((board (generate-board 5 11))
         (placement (queens-board-placement board)))
    (loop for row from 0
          for col in placement
          do (is (= row (region-at board row col))))))

(test generate-queens-board-regions-are-contiguous
  "Every region is one connected blob — a real partition for the puzzle,
not scattered cells that happen to share a number."
  (let* ((size 6)
         (board (generate-board size 5))
         (regions (queens-board-regions board)))
    (dotimes (region-id size)
      (let ((cells (loop for r below size append
                          (loop for c below size
                                when (= region-id (aref regions (+ (* r size) c)))
                                  collect (cons r c))))
            (visited nil))
        (labels ((flood (cell)
                   (unless (member cell visited :test #'equal)
                     (push cell visited)
                     (dolist (n (list (cons (1+ (car cell)) (cdr cell))
                                       (cons (1- (car cell)) (cdr cell))
                                       (cons (car cell) (1+ (cdr cell)))
                                       (cons (car cell) (1- (cdr cell)))))
                       (when (member n cells :test #'equal) (flood n))))))
          (flood (first cells)))
        (is (= (length cells) (length visited))
            "region ~D has ~D cells but only ~D are reachable from each other"
            region-id (length cells) (length visited))))))
