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
      (is (every #'null (rest rows))))))
