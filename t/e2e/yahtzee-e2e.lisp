(in-package :edm-engine/e2e)

(fiveam:in-suite :edm-engine-e2e)

;;; #53's own named gap: zero e2e coverage existed for Hearts/Queens/
;;; Yahtzee gameplay before this file. This specific scenario — win,
;;; popup, celebration overlay — is the exact path that hid both real
;;; bugs found and fixed this session (#54's popup opacity, #46's
;;; confetti z-order): unit tests couldn't catch either, since both
;;; were about what actually gets drawn in the real, running arcade
;;; loop, not about any pure function's return value.

(fiveam:test yahtzee-win-opens-popup-and-spawns-confetti
  "Real regression guard for #54/#46's own bugs, not a new feature
test — this scenario already worked, verified manually, by the time
this test was written; its job is making sure it keeps working. Checks
the two state-level properties that are actually testable without
pixel inspection: the win transition opens the popup (the bug -- a
mode that silently doesn't trigger -- #54's OWN root cause depended
on this happening at all), and the celebration arena genuinely holds
live particles afterward (confirming SPAWNCONFETTI fired, the other
half of what #46's bug required to be true before its own real
bug -- the particles being invisible despite existing -- could even
be checked)."
  (let (reached-playing popup-opened-after-win particles-spawned)
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
         (send-key display +key-down+) ; Hearts -> Yahtzee
         (send-key display +key-return+) ; -> difficulty (Yahtzee is AI-capable)
         (wait-for (lambda () (eq :difficulty (edm-engine:arcade-state-mode state))))
         (send-key display +key-return+) ; confirm tier -> launch
         (setf reached-playing (wait-for (lambda () (eq :playing (edm-engine:arcade-state-mode state)))))
         (let ((game (edm-engine:arcade-state-current-game state)))
           (setf (edm-engine/games/yahtzee::yahtzee-game-status game) :won)
           (setf popup-opened-after-win
                 (wait-for (lambda () (edm-engine:arcade-state-popup-open state))))
           (setf particles-spawned
                 (wait-for
                  (lambda ()
                    (plusp (length (edm-engine:arena-live-handles
                                     edm-engine/games/yahtzee::*confettiArena*))))))))
       (funcall stop)))
    (fiveam:is (not (null reached-playing)))
    (fiveam:is (not (null popup-opened-after-win)))
    (fiveam:is (not (null particles-spawned)))))
