(in-package :edm-engine/games/hearts/tests)
(in-suite :edm-engine-hearts)

(test make-hearts-game-deals-13-to-each-of-4-players
  (let ((game (make-hearts-game :seed 1)))
    (is (= 4 (length (hearts-game-hands game))))
    (is (every (lambda (h) (= 13 (length h))) (hearts-game-hands game)))))

(test make-hearts-game-starts-in-passing-phase-except-round-4-cycle
  (let ((game (make-hearts-game :seed 1 :round 1)))
    (is (eq :passing (hearts-game-phase game))))
  (let ((game (make-hearts-game :seed 1 :round 4)))
    (is (eq :playing (hearts-game-phase game)) "round 4 is a no-pass round")))

(test player-holding-two-of-clubs-leads-first-trick
  (let* ((game (make-hearts-game :seed 1 :round 4))) ; :none pass, straight to play
    (is (find (cons 2 :clubs) (nth (hearts-game-leader game) (hearts-game-hands game)) :test #'equal))))

(test play-card-removes-it-from-hand-and-adds-to-trick
  (let* ((game (make-hearts-game :seed 1 :round 4))
         (leader (hearts-game-leader game))
         (card (cons 2 :clubs)))
    (play-card game leader card)
    (is (not (member card (nth leader (hearts-game-hands game)) :test #'equal)))
    (is (member card (hearts-game-current-trick game) :test #'equal))))

(test play-card-advances-turn-to-next-player
  (let* ((game (make-hearts-game :seed 1 :round 4))
         (leader (hearts-game-leader game)))
    (play-card game leader (cons 2 :clubs))
    (is (= (mod (1+ leader) 4) (hearts-game-turn game)))))

(test completing-a-trick-awards-it-to-the-winner-and-they-lead-next
  (let* ((game (make-hearts-game :seed 1 :round 4)))
    (loop repeat 4
          do (play-card game (hearts-game-turn game)
                        (first (legal-plays (nth (hearts-game-turn game) (hearts-game-hands game))
                                             :led-suit (when (hearts-game-current-trick game)
                                                         (cdr (first (reverse (hearts-game-current-trick game)))))
                                             :hearts-broken (hearts-game-hearts-broken game)
                                             :leading-p (null (hearts-game-current-trick game))))))
    (is (null (hearts-game-current-trick game)) "trick clears once complete")
    (is (= (hearts-game-leader game) (hearts-game-turn game)))))

(test playing-a-heart-breaks-hearts
  (let* ((game (make-hearts-game :seed 1 :round 4)))
    (is (not (hearts-game-hearts-broken game)))
    ;; force a heart into play directly via PLAY-CARD, bypassing legality
    ;; for this narrow test of the HEARTS-BROKEN side effect
    (let ((leader (hearts-game-leader game)))
      (play-card game leader (cons 2 :clubs))
      (dotimes (i 1)
        (let* ((p (hearts-game-turn game))
               (heart (find :hearts (nth p (hearts-game-hands game)) :key #'cdr)))
          (when heart (play-card game p heart) (is (hearts-game-hearts-broken game))))))))

;;; Scoring

(test score-round-assigns-card-points-per-trick-winner
  (let ((game (make-hearts-game :seed 1 :round 4)))
    (dotimes (trick 13)
      (loop repeat 4
            do (play-card game (hearts-game-turn game)
                          (first (legal-plays (nth (hearts-game-turn game) (hearts-game-hands game))
                                               :led-suit (when (hearts-game-current-trick game)
                                                           (cdr (first (reverse (hearts-game-current-trick game)))))
                                               :hearts-broken (hearts-game-hearts-broken game)
                                               :leading-p (null (hearts-game-current-trick game)))))))
    (is (round-over-p game))
    (score-round game)
    (is (= 26 (reduce #'+ (hearts-game-scores game))) "all 26 penalty points distributed somewhere")))

(test shoot-the-moon-detected-when-one-player-takes-all-hearts-and-queen
  (is (shoot-the-moon-p (list 26 0 0 0)))
  (is (not (shoot-the-moon-p (list 13 13 0 0)))))

(test game-over-p-once-someone-reaches-100
  (is (game-over-p (list 100 20 30 10)))
  (is (not (game-over-p (list 99 20 30 10)))))

;;; AI

(test ai-choose-play-returns-a-legal-card
  (let* ((game (make-hearts-game :seed 1 :round 4))
         (leader (hearts-game-leader game))
         (choice (ai-choose-play (nth leader (hearts-game-hands game)) nil (hearts-game-hearts-broken game))))
    (is (member choice (nth leader (hearts-game-hands game)) :test #'equal))))

(test ai-choose-pass-returns-three-distinct-cards-from-hand
  (let* ((hand (first (deal-hands (shuffled-deck 5))))
         (chosen (ai-choose-pass hand)))
    (is (= 3 (length chosen)))
    (is (= 3 (length (remove-duplicates chosen :test #'equal))))
    (is (every (lambda (c) (member c hand :test #'equal)) chosen))))

(test ai-difficulty-persists-after-the-binding-that-set-it-ends
  "Regression test for a real, live-verified bug (#30): *AI-DIFFICULTY*
is only LET-bound for the duration of ARCADE-CONFIRM-DIFFICULTY's
constructor call — MAKE-HEARTS-GAME must capture it into the game's
own slot at that moment, not read the global later once it's reverted.
Simulates exactly the original bug scenario: construct inside a LET
binding a non-default tier, then check the captured value *after* that
binding's dynamic extent has closed, matching how the render layer
reads it many frames later."
  (let (game)
    (let ((edm-engine:*ai-difficulty* :standard))
      (setf game (make-hearts-game :seed 1)))
    (is (eq :standard (hearts-game-ai-difficulty game)))))
