(in-package :edm-engine/e2e)

(fiveam:in-suite :edm-engine-e2e)

;;; #53's own named gap, second slice: Hearts had zero e2e coverage.
;;; Playing a card is the actual, real input path this session's own
;;; #36 retrofit (HAND-CARD-X/#37's ESE-driven avatar glyph) sits
;;; behind — a regression here wouldn't be caught by any pure FiveAM
;;; test, only by driving the real arcade loop.

(fiveam:test hearts-playing-the-two-of-clubs-removes-it-from-the-hand-and-starts-the-trick
  "SEED 8/ROUND 4 chosen deterministically (checked directly, not
guessed): player 0 leads, and the two of clubs sits at hand position 1
— a fixed, known cursor position, not a fragile assumption about hand
order in general. ROUND 4 skips the passing phase entirely (no pass
direction that round), landing straight in :PLAYING, the actual
play-a-card path this test is for."
  (let (reached-playing card-removed-from-hand trick-started)
    (run-arcade-with-driver
     (lambda (state stop)
       (with-x-display (display (e2e-display-name))
         (find-window-by-name display edm-engine:+engine-name+ :timeout 20)
         (send-key display +key-return+) ; dismiss title -> main-menu
         (wait-for (lambda () (eq :main-menu (edm-engine:arcade-state-mode state))))
         (send-key display +key-return+) ; -> tables
         (wait-for (lambda () (eq :tables (edm-engine:arcade-state-mode state))))
         (send-key display +key-down+) ; Wordle -> Queens
         (send-key display +key-down+) ; Queens -> Hearts
         (send-key display +key-return+) ; -> difficulty (Hearts is AI-capable)
         (wait-for (lambda () (eq :difficulty (edm-engine:arcade-state-mode state))))
         (send-key display +key-return+) ; confirm tier -> launch
         (setf reached-playing (wait-for (lambda () (eq :playing (edm-engine:arcade-state-mode state)))))
         (setf (edm-engine:arcade-state-current-game state)
               (edm-engine/games/hearts:make-hearts-game :seed 8 :round 4))
         (let* ((game (edm-engine:arcade-state-current-game state))
                (hand-before (length (first (edm-engine/games/hearts:hearts-game-hands game)))))
           (send-key display +key-right+) ; cursor 0 -> 1, the two of clubs
           (send-key display +key-return+) ; play it
           (setf card-removed-from-hand
                 (wait-for (lambda () (< (length (first (edm-engine/games/hearts:hearts-game-hands game)))
                                          hand-before))))
           (setf trick-started
                 (wait-for (lambda () (plusp (length (edm-engine/games/hearts:hearts-game-current-trick game))))))))
       (funcall stop)))
    (fiveam:is (not (null reached-playing)))
    (fiveam:is (not (null card-removed-from-hand)))
    (fiveam:is (not (null trick-started)))))
