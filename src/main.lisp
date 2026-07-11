(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

(defstruct (arcade-state (:constructor make-arcade-state))
  (mode :menu :type (member :menu :playing))
  (menu-index 0 :type fixnum)
  (current-game nil)
  (ruleset-handle nil))

(defun arcade-select-next (state)
  (when *games*
    (setf (arcade-state-menu-index state)
          (mod (1+ (arcade-state-menu-index state)) (length *games*)))))

(defun arcade-select-previous (state)
  (when *games*
    (setf (arcade-state-menu-index state)
          (mod (1- (arcade-state-menu-index state)) (length *games*)))))

(defun arcade-launch-selected (state)
  (let ((entry (nth (arcade-state-menu-index state) *games*)))
    (when entry
      (let ((game (funcall (game-entry-constructor entry))))
        (setf (arcade-state-current-game state) game
              (arcade-state-ruleset-handle state) (ruleset-load game)
              (arcade-state-mode state) :playing)))))

(defun arcade-return-to-menu (state)
  (ruleset-unload (arcade-state-current-game state) (arcade-state-ruleset-handle state))
  (setf (arcade-state-current-game state) nil
        (arcade-state-ruleset-handle state) nil
        (arcade-state-mode state) :menu))

(defun arcade-update (state)
  (ecase (arcade-state-mode state)
    (:menu
     (when (raylib:is-key-pressed :key-down) (arcade-select-next state))
     (when (raylib:is-key-pressed :key-up) (arcade-select-previous state))
     (when (raylib:is-key-pressed :key-enter) (arcade-launch-selected state)))
    (:playing
     (if (raylib:is-key-pressed :key-escape)
         (arcade-return-to-menu state)
         (game-update (arcade-state-current-game state))))))

(defun arcade-render (state window-width window-height)
  "One BeginDrawing/EndDrawing per frame, established here — GAME-RENDER
methods (e.g. DRAW-GRID) assume they're already inside a drawing context
and never call WITH-DRAWING themselves. Missing this wrapper for the
:PLAYING branch was a real bug: the arcade drew the menu correctly but
never issued a single draw call once a game was launched, since
GAME-RENDER's draw-rectangle/draw-text calls outside BeginDrawing/
EndDrawing don't reach the screen."
  (raylib:with-drawing
    (raylib:clear-background :black)
    (ecase (arcade-state-mode state)
      (:menu
       (loop for entry in *games*
             for i from 0
             do (raylib:draw-text (game-entry-title entry) 40 (+ 40 (* i 36)) 28
                                   (if (= i (arcade-state-menu-index state)) :green :gray))))
      (:playing
       (game-render (arcade-state-current-game state) window-width window-height)))))

(defun main (&rest argv)
  "Boots the arcade: a menu over every REGISTER-GAME entry, dispatching
to the selected game's GAME-UPDATE/GAME-RENDER each frame. This file has
no knowledge of any specific game — that's the whole point."
  (declare (ignore argv))
  (open-window "EDM Arcade" 800 700)
  (unwind-protect
       (let ((state (make-arcade-state)))
         (loop until (window-should-close-p)
               do (arcade-update state)
                  (arcade-render state 800 700)))
    (close-window))
  (uiop:quit 0))
