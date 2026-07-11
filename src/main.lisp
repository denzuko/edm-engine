(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

(defun main (&rest argv)
  "Boots the arcade: opens a window, ticks a demo arena until close.
Per-game rulesets attach via RULESET-LOAD/RULESET-UNLOAD; none is loaded
here yet — this is the bare cabinet shell."
  (declare (ignore argv))
  (open-window "EDM Arcade" 800 600)
  (unwind-protect
       (let ((arena (make-arena 64))
             (clock (make-tick)))
         (loop until (window-should-close-p)
               do (advance-tick arena clock (/ 1.0 60))
                  (draw-arena arena)))
    (close-window))
  (uiop:quit 0))
