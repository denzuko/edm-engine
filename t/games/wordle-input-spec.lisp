(in-package :edm-engine/games/wordle/tests)
(in-suite :edm-engine-wordle)

(test push-letter-appends-uppercased-when-room
  (let ((game (make-wordle-game "CRANE")))
    (push-letter game #\c)
    (is (string= "C" (coerce (wordle-game-input game) 'string)))))

(test push-letter-ignores-non-alpha
  (let ((game (make-wordle-game "CRANE")))
    (push-letter game #\1)
    (is (= 0 (fill-pointer (wordle-game-input game))))))

(test push-letter-stops-at-answer-length
  (let ((game (make-wordle-game "CRANE")))
    (dotimes (i 7) (push-letter game #\A))
    (is (= 5 (fill-pointer (wordle-game-input game))))))

(test push-letter-ignores-when-game-finished
  (let ((game (make-wordle-game "CRANE" :max-rows 1)))
    (submit-guess game "CRANE")
    (is (eq :won (wordle-game-status game)))
    (push-letter game #\A)
    (is (= 0 (fill-pointer (wordle-game-input game))))))

(test pop-letter-removes-last-when-present
  (let ((game (make-wordle-game "CRANE")))
    (push-letter game #\C)
    (push-letter game #\R)
    (pop-letter game)
    (is (string= "C" (coerce (wordle-game-input game) 'string)))))

(test pop-letter-no-op-when-empty
  (let ((game (make-wordle-game "CRANE")))
    (pop-letter game)
    (is (= 0 (fill-pointer (wordle-game-input game))))))

(test try-submit-only-fires-when-input-length-matches-answer
  (let ((game (make-wordle-game "CRANE")))
    (push-letter game #\C) (push-letter game #\R)
    (try-submit game)
    (is (= 0 (length (wordle-game-history game))))
    (is (= 2 (fill-pointer (wordle-game-input game))))))

(test try-submit-clears-input-and-appends-history-when-ready
  (let ((game (make-wordle-game "CRANE")))
    (loop for ch across "STEED" do (push-letter game ch))
    (try-submit game)
    (is (= 0 (fill-pointer (wordle-game-input game))))
    (is (= 1 (length (wordle-game-history game))))))

(test try-submit-drives-game-to-won
  (let ((game (make-wordle-game "CRANE" :max-rows 1)))
    (loop for ch across "CRANE" do (push-letter game ch))
    (try-submit game)
    (is (eq :won (wordle-game-status game)))))
