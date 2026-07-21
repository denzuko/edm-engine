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

;;; #9's piece 2, continuing — real GAME-SAVE-DATA/RESTORE-FN for
;;; Hearts. Unlike Queens' board, Hearts' dealt/passed/played hands
;;; can't be regenerated from SEED+ROUND alone once play has modified
;;; them — the full live state is captured directly, not reconstructed.

(test hearts-save-data-captures-real-in-progress-state
  "GOAL: GAME-SAVE-DATA must reflect genuine mid-game state -- a card
actually played, not values that happen to match a freshly-dealt
game."
  (let ((game (make-hearts-game :seed 8 :round 4))) ; leader=0, deterministic, checked directly earlier this session
    (let ((hand-before (length (first (hearts-game-hands game)))))
      (play-card game 0 (cons 2 :clubs))
      (let ((data (edm-engine:game-save-data game)))
        (is (< (length (first (getf data :hands))) hand-before))
        (is (eq :playing (getf data :phase)))
        (is (= 4 (getf data :round)))))))

(test hearts-restore-game-round-trips-real-mid-trick-state-exactly
  "GOAL: hands, scores, the in-progress trick, turn, and AI difficulty
all survive a real save/restore round trip -- one combined scenario,
not each field verified in isolation and assumed to compose correctly."
  (let ((game (make-hearts-game :seed 8 :round 4)))
    (play-card game 0 (cons 2 :clubs))
    (let* ((data (edm-engine:game-save-data game))
           (restored (edm-engine/games/hearts::hearts-restore-game data)))
      (is (equal (hearts-game-hands game) (hearts-game-hands restored)))
      (is (equal (hearts-game-scores game) (hearts-game-scores restored)))
      (is (equal (hearts-game-current-trick game) (hearts-game-current-trick restored)))
      (is (= (hearts-game-leader game) (hearts-game-leader restored)))
      (is (= (hearts-game-turn game) (hearts-game-turn restored)))
      (is (eq (hearts-game-hearts-broken game) (hearts-game-hearts-broken restored)))
      (is (= (hearts-game-round game) (hearts-game-round restored)))
      (is (eq (hearts-game-phase game) (hearts-game-phase restored)))
      (is (eq (hearts-game-status game) (hearts-game-status restored)))
      (is (eq (hearts-game-ai-difficulty game) (hearts-game-ai-difficulty restored))))))
