(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

(defun main (&rest argv)
  "Boots the arcade: opens a window, plays Wordle until close.
Per-game rulesets attach via RULESET-LOAD/RULESET-UNLOAD — Wordle needs
neither (see edm-engine/ruleset docstring), so this loop talks to
WORDLE-GAME directly. Future constraint-based games route through the
ruleset protocol instead."
  (declare (ignore argv))
  (open-window "EDM Arcade — Wordle" 800 700)
  (unwind-protect
       (let ((game (edm-engine/games/wordle:make-wordle-game
                    (nth (random (length edm-engine/games/wordle:*corpus*))
                         edm-engine/games/wordle:*corpus*)))
             (input (make-array 0 :element-type 'character :adjustable t :fill-pointer 0)))
         (loop until (window-should-close-p)
               do (loop for code = (raylib:get-char-pressed)
                        while (plusp code)
                        do (let ((ch (char-upcase (code-char code))))
                             (when (and (alpha-char-p ch) (< (fill-pointer input) 5))
                               (vector-push-extend ch input))))
                  (when (and (raylib:is-key-pressed :key-backspace)
                             (plusp (fill-pointer input)))
                    (decf (fill-pointer input)))
                  (when (and (raylib:is-key-pressed :key-enter)
                             (= 5 (fill-pointer input))
                             (eq :playing (edm-engine/games/wordle:wordle-game-status game)))
                    (edm-engine/games/wordle:submit-guess game (coerce input 'string))
                    (setf (fill-pointer input) 0))
                  (raylib:with-drawing
                    (raylib:clear-background :black)
                    (edm-engine/games/wordle:draw-grid
                     800 700 (edm-engine/games/wordle:rows-for-render game)))))
    (close-window))
  (uiop:quit 0))
