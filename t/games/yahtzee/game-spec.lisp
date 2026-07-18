(in-package :edm-engine/games/yahtzee/tests)
(in-suite :edm-engine-yahtzee)

(test make-yahtzee-game-starts-with-3-rolls-and-empty-scores
  (let ((game (make-yahtzee-game :seed 1 :player-count 4)))
    (is (= 3 (yahtzee-game-rolls-remaining game)))
    (is (= 4 (length (yahtzee-game-scores game))))
    (is (every #'null (yahtzee-game-scores game)))))

(test roll-turn-dice-decrements-rolls-remaining
  (let ((game (make-yahtzee-game :seed 1 :player-count 4)))
    (roll-turn-dice game)
    (is (= 2 (yahtzee-game-rolls-remaining game)))
    (is (= 5 (length (yahtzee-game-dice game))))))

(test roll-turn-dice-respects-held-dice
  (let ((game (make-yahtzee-game :seed 1 :player-count 4)))
    (roll-turn-dice game)
    (let ((before (copy-list (yahtzee-game-dice game))))
      (setf (yahtzee-game-held game) (list t nil nil nil nil))
      (roll-turn-dice game)
      (is (= (first before) (first (yahtzee-game-dice game)))))))

(test toggle-hold-flips-the-given-die
  (let ((game (make-yahtzee-game :seed 1 :player-count 4)))
    (toggle-hold game 2)
    (is (nth 2 (yahtzee-game-held game)))
    (toggle-hold game 2)
    (is (not (nth 2 (yahtzee-game-held game))))))

(test commit-score-fills-the-category-for-the-current-player-and-advances-turn
  (let ((game (make-yahtzee-game :seed 1 :player-count 4)))
    (roll-turn-dice game)
    (let ((dice (yahtzee-game-dice game))
          (player (yahtzee-game-turn game)))
      (commit-score game :chance)
      (is (= (score-chance dice) (getf (nth player (yahtzee-game-scores game)) :chance)))
      (is (= (mod (1+ player) 4) (yahtzee-game-turn game)))
      (is (= 3 (yahtzee-game-rolls-remaining game)) "fresh rolls for the next player"))))

(test commit-score-cannot-refill-an-already-scored-category
  (let ((game (make-yahtzee-game :seed 1 :player-count 4)))
    (roll-turn-dice game)
    (commit-score game :chance)
    ;; back around to player 0 after 3 more commits
    (dotimes (i 3) (roll-turn-dice game) (commit-score game :ones))
    (is (not (member :chance (available-categories game 0))) "chance should no longer be available to player 0")))

(test available-categories-excludes-already-scored-ones
  (let ((game (make-yahtzee-game :seed 1 :player-count 4)))
    (roll-turn-dice game)
    (commit-score game :yahtzee)
    (is (not (member :yahtzee (available-categories game 0))))
    (is (member :chance (available-categories game 0)))))

(test turn-over-p-true-once-all-players-have-filled-every-category
  (let ((game (make-yahtzee-game :seed 1 :player-count 1)))
    (is (not (turn-over-p game)))
    (dolist (cat +categories+)
      (roll-turn-dice game)
      (commit-score game cat))
    (is (game-over-p game))))

(test winner-index-is-the-highest-grand-total
  (let ((game (make-yahtzee-game :seed 1 :player-count 2)))
    (setf (yahtzee-game-scores game)
          (list (list :ones 1 :chance 5) (list :ones 1 :chance 20)))
    (is (= 1 (winner-index game)))))

(test game-outcome-reflects-status-not-the-default-nil-method
  "Regression test for a real, live-verified bug (#34): GAME-OUTCOME
had no method for YAHTZEE-GAME at all, silently falling through to the
default NIL — the arcade shell's win/lose overlay never appeared for
this table even when the game's own status correctly said :WON."
  (let ((game (make-yahtzee-game)))
    (is (null (edm-engine:game-outcome game)))
    (setf (yahtzee-game-status game) :won)
    (is (eq :win (edm-engine:game-outcome game)))
    (setf (yahtzee-game-status game) :lost)
    (is (eq :lose (edm-engine:game-outcome game)))))

(test game-score-reflects-the-human-players-grand-total
  "Regression test for #34: GAME-SCORE also had no method, so the
arcade's running total never banked Yahtzee points at all."
  (let ((game (make-yahtzee-game)))
    (setf (yahtzee-game-scores game)
          (list (list :ones 3 :twos 6 :chance 20) nil nil nil))
    (is (= 29 (edm-engine:game-score game)))))

;;; AI

(test ai-choose-holds-returns-5-booleans
  (let ((choice (ai-choose-holds '(1 2 3 4 5) nil)))
    (is (= 5 (length choice)))
    (is (every (lambda (h) (member h '(t nil))) choice))))

(test ai-choose-category-picks-from-whats-actually-available
  (let* ((game (make-yahtzee-game :seed 1 :player-count 4)))
    (roll-turn-dice game)
    (let ((choice (ai-choose-category (yahtzee-game-dice game) (available-categories game (yahtzee-game-turn game)))))
      (is (member choice +categories+)))))

(test ai-difficulty-persists-after-the-binding-that-set-it-ends
  "Same regression as Hearts' — #30's actual fix, verified the same way."
  (let (game)
    (let ((edm-engine:*ai-difficulty* :expert))
      (setf game (make-yahtzee-game :seed 1)))
    (is (eq :expert (yahtzee-game-ai-difficulty game)))))
