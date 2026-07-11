(in-package :edm-engine/games/wordle/tests)
(in-suite :edm-engine-wordle)

(test submit-guess-appends-history-with-feedback
  (let ((game (make-wordle-game "CRANE")))
    (submit-guess game "STEED")
    (is (= 1 (length (wordle-game-history game))))
    (is (equalp (evaluate-guess "STEED" "CRANE") (cdr (first (wordle-game-history game)))))))

(test submit-guess-wins-when-guess-matches-answer
  (let ((game (make-wordle-game "CRANE")))
    (submit-guess game "STEED")
    (is (eq :playing (wordle-game-status game)))
    (submit-guess game "CRANE")
    (is (eq :won (wordle-game-status game)))))

(test submit-guess-loses-after-max-rows-without-winning
  (let ((game (make-wordle-game "CRANE" :max-rows 2)))
    (submit-guess game "STEED")
    (is (eq :playing (wordle-game-status game)))
    (submit-guess game "TRAIN")
    (is (eq :lost (wordle-game-status game)))))

(test submit-guess-errors-once-game-is-finished
  (let ((game (make-wordle-game "CRANE" :max-rows 1)))
    (submit-guess game "CRANE")
    (is (eq :won (wordle-game-status game)))
    (signals error (submit-guess game "STEED"))))

(test submit-guess-errors-on-wrong-length
  (let ((game (make-wordle-game "CRANE")))
    (signals error (submit-guess game "TOOLONG"))))

(test rows-for-render-fills-played-rows-and-pads-the-rest
  (let ((game (make-wordle-game "CRANE" :max-rows 6)))
    (submit-guess game "STEED")
    (let* ((rows (rows-for-render game))
           (expected-feedback (evaluate-guess "STEED" "CRANE")))
      (is (= 6 (length rows)))
      (is (equalp (loop for ch across "STEED"
                         for st across expected-feedback
                         collect (cons ch st))
                  (first rows)))
      ;; padding rows are always COLS-wide with NIL cells, never a bare
      ;; NIL row — draw-grid's per-row loop draws zero tiles for a bare
      ;; NIL row, silently skipping unplayed rows entirely.
      (is (every (lambda (row) (and (= 5 (length row)) (every #'null row)))
                 (rest rows))))))

(test rows-for-render-shows-in-progress-input-as-a-row
  (let ((game (make-wordle-game "CRANE")))
    (push-letter game #\S)
    (push-letter game #\T)
    (let ((row (first (rows-for-render game))))
      (is (equal (cons #\S :empty) (first row)))
      (is (equal (cons #\T :empty) (second row)))
      (is (null (third row)))
      (is (= 5 (length row))))))

(test rows-for-render-in-progress-row-follows-played-rows
  (let ((game (make-wordle-game "CRANE" :max-rows 6)))
    (submit-guess game "STEED")
    (push-letter game #\C)
    (let ((rows (rows-for-render game)))
      (is (equal (cons #\C :empty) (first (second rows))))
      (is (= 6 (length rows))))))

(test push-letter-resets-pulse-to-max
  (let ((game (make-wordle-game "CRANE")))
    (is (= 0 (wordle-game-pulse game)))
    (push-letter game #\C)
    (is (= +pulse-max+ (wordle-game-pulse game)))))

(test tick-pulse-decrements-toward-zero-and-stops
  (let ((game (make-wordle-game "CRANE")))
    (push-letter game #\C)
    (dotimes (i (+ +pulse-max+ 3))
      (tick-pulse game))
    (is (= 0 (wordle-game-pulse game)))))

(test game-outcome-nil-while-playing
  (let ((game (make-wordle-game "CRANE")))
    (is (null (edm-engine:game-outcome game)))))

(test game-outcome-win-when-status-won
  (let ((game (make-wordle-game "CRANE" :max-rows 1)))
    (submit-guess game "CRANE")
    (is (eq :win (edm-engine:game-outcome game)))))

(test game-outcome-lose-when-status-lost
  (let ((game (make-wordle-game "CRANE" :max-rows 1)))
    (submit-guess game "STEED")
    (is (eq :lost (wordle-game-status game)))
    (is (eq :lose (edm-engine:game-outcome game)))))

;; boundary case flagged as undertested: winning on the very last
;; available row should still resolve to :won, not :lost — the win
;; check in submit-guess must run before the max-rows exhaustion check.
(test winning-on-the-final-row-resolves-to-won-not-lost
  (let ((game (make-wordle-game "CRANE" :max-rows 1)))
    (submit-guess game "CRANE")
    (is (eq :won (wordle-game-status game)))
    (is (eq :win (edm-engine:game-outcome game)))))

;; boundary: exhausting all rows on the LAST allowed guess without
;; matching must resolve to :lost, not stay :playing due to an
;; off-by-one in the >= comparison.
(test losing-exactly-at-the-final-row-resolves-to-lost
  (let ((game (make-wordle-game "CRANE" :max-rows 3)))
    (submit-guess game "STEED")
    (submit-guess game "TRAIN")
    (is (eq :playing (wordle-game-status game)))
    (submit-guess game "SPARE")
    (is (eq :lost (wordle-game-status game)))))

;; push-letter/pop-letter/try-submit must all become no-ops once the
;; game has an outcome — this was asserted individually before but
;; never as a single "finished game is fully frozen" scenario.
(test finished-game-ignores-all-further-input
  (let ((game (make-wordle-game "CRANE" :max-rows 1)))
    (submit-guess game "CRANE")
    (push-letter game #\X)
    (is (= 0 (fill-pointer (wordle-game-input game))))
    (pop-letter game)
    (is (= 0 (fill-pointer (wordle-game-input game))))
    (try-submit game)
    (is (= 1 (length (wordle-game-history game))))))
