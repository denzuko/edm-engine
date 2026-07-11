(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

(defun arcade-update (state)
  (ecase (arcade-state-mode state)
    (:main-menu
     (when (raylib:is-key-pressed :key-down) (arcade-select-next-main-menu state))
     (when (raylib:is-key-pressed :key-up) (arcade-select-previous-main-menu state))
     (when (raylib:is-key-pressed :key-enter) (arcade-drill-into-main-menu-selection state)))
    (:tables
     (when (raylib:is-key-pressed :key-down) (arcade-select-next-table state))
     (when (raylib:is-key-pressed :key-up) (arcade-select-previous-table state))
     (when (raylib:is-key-pressed :key-enter) (arcade-launch-selected state))
     (when (raylib:is-key-pressed :key-escape) (arcade-back-to-main-menu state)))
    ((:options :save-load)
     (when (raylib:is-key-pressed :key-escape) (arcade-back-to-main-menu state)))
    (:playing
     (let ((game (arcade-state-current-game state)))
       (if (game-outcome game)
           (cond ((raylib:is-key-pressed :key-enter) (arcade-restart-current state))
                 ((raylib:is-key-pressed :key-escape) (arcade-return-to-table-select state)))
           (if (raylib:is-key-pressed :key-escape)
               (arcade-return-to-table-select state)
               (game-update game)))))))

(defun draw-outcome-overlay (outcome window-width window-height)
  (let ((label (ecase outcome (:win "YOU WON") (:lose "YOU LOST") (:tie "TIE GAME"))))
    (raylib:draw-rectangle 0 0 window-width window-height (raylib:fade :black 0.55))
    (let ((tw (raylib:measure-text label 48)))
      (raylib:draw-text label (round (/ (- window-width tw) 2))
                         (round (- (/ window-height 2) 60)) 48 :white))
    (let* ((hint "ENTER: New Game    ESC: Table Select")
           (hw (raylib:measure-text hint 22)))
      (raylib:draw-text hint (round (/ (- window-width hw) 2))
                         (round (+ (/ window-height 2) 10)) 22 :gray))))

(defun arcade-render (state window-width window-height)
  "One BeginDrawing/EndDrawing per frame, established here — GAME-RENDER
methods (e.g. DRAW-GRID) assume they're already inside a drawing context
and never call WITH-DRAWING themselves."
  (raylib:with-drawing
    (raylib:clear-background :black)
    (ecase (arcade-state-mode state)
      (:main-menu
       (raylib:draw-text +engine-name+ 40 30 34 :green)
       (loop for item in +main-menu-items+
             for i from 0
             do (raylib:draw-text item 40 (+ 100 (* i 40)) 28
                                   (if (= i (arcade-state-main-menu-index state)) :green :gray))))
      (:tables
       (raylib:draw-text "TABLES" 40 30 30 :green)
       (loop for entry in *games*
             for i from 0
             do (raylib:draw-text (game-entry-title entry) 40 (+ 90 (* i 36)) 26
                                   (if (= i (arcade-state-table-index state)) :green :gray)))
       (raylib:draw-text "ESC: Back" 40 (- window-height 40) 18 :gray))
      (:options
       (raylib:draw-text "ENGINE OPTIONS" 40 30 30 :green)
       (raylib:draw-text "Coming soon." 40 100 22 :gray)
       (raylib:draw-text "ESC: Back" 40 (- window-height 40) 18 :gray))
      (:save-load
       (raylib:draw-text "SAVE / LOAD" 40 30 30 :green)
       (raylib:draw-text "Coming soon." 40 100 22 :gray)
       (raylib:draw-text "ESC: Back" 40 (- window-height 40) 18 :gray))
      (:playing
       (let ((game (arcade-state-current-game state)))
         (game-render game window-width window-height)
         (let ((outcome (game-outcome game)))
           (when outcome (draw-outcome-overlay outcome window-width window-height))))))))

(defun main (&rest argv)
  "Boots the arcade: a main menu (Tables / Engine Options / Save-Load)
over every REGISTER-GAME entry, dispatching to the selected table's
GAME-UPDATE/GAME-RENDER each frame. This file has no knowledge of any
specific table — that's the whole point."
  (declare (ignore argv))
  (open-window (format nil "~A" +engine-name+) 800 700)
  (unwind-protect
       (let ((state (make-arcade-state)))
         (loop until (window-should-close-p)
               do (arcade-update state)
                  (arcade-render state 800 700)))
    (close-window))
  (uiop:quit 0))
