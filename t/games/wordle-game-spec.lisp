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

;; corpus/dictionary validation — a guess must be a real word, not just
;; the right length. Flagged as untested: previously ANY 5-letter string
;; was accepted.
(test valid-word-p-true-for-corpus-member
  (is (valid-word-p "CRANE" '("CRANE" "TRAIN"))))

(test valid-word-p-false-for-non-member
  (is (not (valid-word-p "ZZZZZ" '("CRANE" "TRAIN")))))

(test valid-word-p-case-insensitive
  (is (valid-word-p "crane" '("CRANE" "TRAIN"))))

(test submit-guess-signals-invalid-word-for-non-corpus-guess
  (let ((game (make-wordle-game "CRANE" :corpus '("CRANE" "TRAIN"))))
    (signals invalid-word (submit-guess game "ZZZZZ"))))

(test submit-guess-does-not-mutate-state-on-invalid-word
  (let ((game (make-wordle-game "CRANE" :corpus '("CRANE" "TRAIN"))))
    (handler-case (submit-guess game "ZZZZZ") (invalid-word ()))
    (is (= 0 (length (wordle-game-history game))))
    (is (eq :playing (wordle-game-status game)))))

(test try-submit-returns-rejected-and-keeps-input-on-invalid-word
  (let ((game (make-wordle-game "CRANE" :corpus '("CRANE" "TRAIN"))))
    (loop for ch across "ZZZZZ" do (push-letter game ch))
    (is (eq :rejected (try-submit game)))
    (is (= 5 (fill-pointer (wordle-game-input game))))
    (is (= 0 (length (wordle-game-history game))))))

(test try-submit-returns-submitted-on-valid-word
  (let ((game (make-wordle-game "CRANE" :corpus '("CRANE" "TRAIN"))))
    (loop for ch across "TRAIN" do (push-letter game ch))
    (is (eq :submitted (try-submit game)))))

(test try-submit-returns-not-ready-when-input-incomplete
  (let ((game (make-wordle-game "CRANE")))
    (push-letter game #\C)
    (is (eq :not-ready (try-submit game)))))

;; scoring
(test game-score-zero-while-playing
  (let ((game (make-wordle-game "CRANE" :corpus '("CRANE"))))
    (is (= 0 (edm-engine:game-score game)))))

(test game-score-zero-on-loss
  (let ((game (make-wordle-game "CRANE" :max-rows 1 :corpus '("CRANE" "STEED"))))
    (submit-guess game "STEED")
    (is (eq :lost (wordle-game-status game)))
    (is (= 0 (edm-engine:game-score game)))))

(test game-score-rewards-fewer-guesses
  (let ((fast (make-wordle-game "CRANE" :max-rows 6 :corpus '("CRANE" "STEED" "TRAIN" "SPARE")))
        (slow (make-wordle-game "CRANE" :max-rows 6 :corpus '("CRANE" "STEED" "TRAIN" "SPARE"))))
    (submit-guess fast "CRANE")
    (submit-guess slow "STEED")
    (submit-guess slow "TRAIN")
    (submit-guess slow "SPARE")
    (submit-guess slow "CRANE")
    (is (> (edm-engine:game-score fast) (edm-engine:game-score slow)))
    (is (> (edm-engine:game-score slow) 0))))

;; save/restore round trip
(test game-save-data-round-trips-through-wordle-restore-game
  (let ((game (make-wordle-game "CRANE" :corpus '("CRANE" "STEED"))))
    (submit-guess game "STEED")
    (let* ((saved (edm-engine:game-save-data game))
           (restored (wordle-restore-game saved)))
      (is (string= (wordle-game-answer game) (wordle-game-answer restored)))
      (is (equalp (wordle-game-history game) (wordle-game-history restored)))
      (is (eq (wordle-game-status game) (wordle-game-status restored))))))
