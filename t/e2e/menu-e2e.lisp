(in-package :edm-engine/e2e)

(fiveam:def-suite :edm-engine-e2e)
(fiveam:in-suite :edm-engine-e2e)

(defun e2e-display-name ()
  (or (sb-ext:posix-getenv "DISPLAY") ":99"))

;; FIVEAM:IS relies on a dynamic binding FIVEAM:TEST establishes on the
;; calling thread; it can't be called from the driver lambda, which runs
;; on a bordeaux-threads worker. Every test below collects plain values
;; inside the driver, then asserts on them after RUN-ARCADE-WITH-DRIVER
;; returns (which blocks until both threads finish), back on the
;; original test thread.

(fiveam:test menu-enter-navigates-from-main-menu-to-tables
  "Real XTEST key event -> real GLFW/raylib key detection -> real
ARCADE-UPDATE dispatch -> real state mutation. This is the actual
input path GAME-UPDATE's raylib reads take; the FiveAM suite for the
pure ARCADE-DRILL-INTO-MAIN-MENU-SELECTION function already covers the
logic, this covers that real keystrokes actually reach it."
  (let (window-found initial-mode reached-tables)
    (run-arcade-with-driver
     (lambda (state stop)
       (with-x-display (display (e2e-display-name))
         (setf window-found (not (null (find-window-by-name display edm-engine:+engine-name+ :timeout 20))))
         (setf initial-mode (edm-engine:arcade-state-mode state))
         (send-key display +key-return+)
         (setf reached-tables (wait-for (lambda () (eq :tables (edm-engine:arcade-state-mode state))))))
       (funcall stop)))
    (fiveam:is (not (null window-found)))
    (fiveam:is (eq :main-menu initial-mode))
    (fiveam:is (not (null reached-tables)))))

(fiveam:test menu-down-wraps-selection-through-all-three-items
  (let (r1 r2 r3)
    (run-arcade-with-driver
     (lambda (state stop)
       (with-x-display (display (e2e-display-name))
         (find-window-by-name display edm-engine:+engine-name+ :timeout 20)
         (send-key display +key-down+)
         (setf r1 (wait-for (lambda () (= 1 (edm-engine:arcade-state-main-menu-index state)))))
         (send-key display +key-down+)
         (setf r2 (wait-for (lambda () (= 2 (edm-engine:arcade-state-main-menu-index state)))))
         (send-key display +key-down+)
         (setf r3 (wait-for (lambda () (= 0 (edm-engine:arcade-state-main-menu-index state))))))
       (funcall stop)))
    (fiveam:is (not (null r1))) (fiveam:is (not (null r2))) (fiveam:is (not (null r3)))))

(fiveam:test wordle-real-typed-letters-and-submit-reach-game-history
  "Proves GET-CHAR-PRESSED's real event path, not just KEY events —
this is what actually types a Wordle guess, and was the one input
class never confirmed end-to-end through the earlier xdotool sessions
this same way."
  (let (result)
    (run-arcade-with-driver
     (lambda (state stop)
       (with-x-display (display (e2e-display-name))
         (find-window-by-name display edm-engine:+engine-name+ :timeout 20)
         (send-key display +key-return+) ; -> tables
         (wait-for (lambda () (eq :tables (edm-engine:arcade-state-mode state))))
         (send-key display +key-return+) ; launch first table (Wordle)
         (wait-for (lambda () (eq :playing (edm-engine:arcade-state-mode state))))
         (setf (edm-engine/games/wordle::wordle-game-answer
                (edm-engine:arcade-state-current-game state))
               "CRANE")
         (send-text display "train")
         (send-key display +key-return+)
         (setf result
               (wait-for
                (lambda ()
                  (= 1 (length (edm-engine/games/wordle:wordle-game-history
                                (edm-engine:arcade-state-current-game state)))))
                :timeout 5)))
       (funcall stop)))
    (fiveam:is (not (null result)))))

(fiveam:test wordle-real-typed-letter-actually-triggers-audio-device-init
  "AUDIO:*AUDIO-DEVICE-READY* only flips T inside PLAY-TONE, called only
from GAME-UPDATE's real key-read branches — a regression guard against
silently breaking the audio wiring the way the direct-call demo scripts
did (they never triggered it at all, discovered only by grepping logs
by hand)."
  (let (result)
    (run-arcade-with-driver
     (lambda (state stop)
       (with-x-display (display (e2e-display-name))
         (find-window-by-name display edm-engine:+engine-name+ :timeout 20)
         (send-key display +key-return+)
         (wait-for (lambda () (eq :tables (edm-engine:arcade-state-mode state))))
         (send-key display +key-return+)
         (wait-for (lambda () (eq :playing (edm-engine:arcade-state-mode state))))
         (send-char display #\a)
         (setf result (wait-for (lambda () edm-engine/audio:*audio-device-ready*) :timeout 5)))
       (funcall stop)))
    (fiveam:is (not (null result)))))

(fiveam:test escape-opens-pause-popup-and-resume-does-not-kill-the-loop
  "Regression guard: raylib's default ESC-closes-window silently killed
the whole arcade loop the instant a pause-menu ESC fired, since
WINDOW-SHOULD-CLOSE-P returns T on ESC independent of any
IS-KEY-PRESSED check. Every gameplay action sent after that point went
into a loop that had already stopped updating state — three
unrelated-looking symptoms (a full loss, a win, and volume adjustment
all silently failing) turned out to be this one bug."
  (let (popup-opened-correctly resumed-correctly typed-after-resume history-after)
    (run-arcade-with-driver
     (lambda (state stop)
       (with-x-display (display (e2e-display-name))
         (find-window-by-name display edm-engine:+engine-name+ :timeout 20)
         (send-key display +key-return+)
         (wait-for (lambda () (eq :tables (edm-engine:arcade-state-mode state))))
         (send-key display +key-return+)
         (wait-for (lambda () (eq :playing (edm-engine:arcade-state-mode state))))
         (let ((game (edm-engine:arcade-state-current-game state)))
           (setf (edm-engine/games/wordle::wordle-game-answer game) "CRANE")
           (send-key display +key-escape+)
           (setf popup-opened-correctly (wait-for (lambda () (edm-engine:arcade-state-popup-open state))))
           (send-key display +key-return+) ; Resume
           (setf resumed-correctly (wait-for (lambda () (not (edm-engine:arcade-state-popup-open state)))))
           (send-text display "train")
           (setf typed-after-resume
                 (wait-for (lambda () (= 5 (fill-pointer (edm-engine/games/wordle:wordle-game-input game))))))
           (send-key display +key-return+)
           (setf history-after
                 (wait-for (lambda () (= 1 (length (edm-engine/games/wordle:wordle-game-history game))))))))
       (funcall stop)))
    (fiveam:is (not (null popup-opened-correctly)))
    (fiveam:is (not (null resumed-correctly)))
    (fiveam:is (not (null typed-after-resume)))
    (fiveam:is (not (null history-after)))))
