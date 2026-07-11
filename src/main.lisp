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
    (:options
     (when (raylib:is-key-pressed :key-right)
       (arcade-increase-volume state)
       (edm-engine/audio:ensure-audio-device)
       (raylib:set-master-volume (arcade-state-volume state)))
     (when (raylib:is-key-pressed :key-left)
       (arcade-decrease-volume state)
       (edm-engine/audio:ensure-audio-device)
       (raylib:set-master-volume (arcade-state-volume state)))
     (when (raylib:is-key-pressed :key-escape) (arcade-back-to-main-menu state)))
    (:save-load
     (when (raylib:is-key-pressed :key-enter) (arcade-load-saved-game state))
     (when (raylib:is-key-pressed :key-escape) (arcade-back-to-main-menu state)))
    (:playing
     (let ((game (arcade-state-current-game state)))
       (cond
         ((arcade-state-popup-open state)
          (when (raylib:is-key-pressed :key-down) (arcade-popup-next state))
          (when (raylib:is-key-pressed :key-up) (arcade-popup-previous state))
          (when (raylib:is-key-pressed :key-enter) (arcade-popup-confirm state)))
         ((game-outcome game) (arcade-open-popup state))
         ((raylib:is-key-pressed :key-escape) (arcade-open-popup state))
         (t (game-update game)))))))

(defun draw-popup-menu (state window-width window-height)
  "Generic pause/outcome menu — New Game / Save State / Return to Tables,
plus Resume while the game's still in progress. No per-game knowledge:
the item list comes from ARCADE-POPUP-ITEMS, driven by GAME-OUTCOME."
  (let* ((game (arcade-state-current-game state))
         (items (arcade-popup-items game))
         (outcome (game-outcome game)))
    (raylib:draw-rectangle 0 0 window-width window-height (raylib:fade :black 0.6))
    (when outcome
      (let* ((label (ecase outcome (:win "YOU WON") (:lose "YOU LOST") (:tie "TIE GAME")))
             (tw (raylib:measure-text label 44)))
        (raylib:draw-text label (round (/ (- window-width tw) 2)) 140 44 :white)))
    (loop for item in items
          for i from 0
          for y = (+ 260 (* i 40))
          do (raylib:draw-text item (round (- (/ window-width 2) 90)) y 28
                                (if (= i (arcade-state-popup-index state)) :green :gray)))))

(defun arcade-render (state window-width window-height)
  "One BeginDrawing/EndDrawing per frame, established here — GAME-RENDER
methods (e.g. DRAW-GRID) assume they're already inside a drawing context
and never call WITH-DRAWING themselves."
  (raylib:with-drawing
    (raylib:clear-background :black)
    (ecase (arcade-state-mode state)
      (:main-menu
       (raylib:draw-text +engine-name+ 40 30 34 :green)
       (raylib:draw-text (format nil "Score: ~D" (arcade-state-total-score state))
                          40 (- window-height 40) 18 :gray)
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
       (raylib:draw-text (format nil "Master Volume: ~D%" (round (* 100 (arcade-state-volume state))))
                          40 100 22 :white)
       (raylib:draw-text "LEFT / RIGHT: Adjust" 40 140 18 :gray)
       (raylib:draw-text "ESC: Back" 40 (- window-height 40) 18 :gray))
      (:save-load
       (raylib:draw-text "SAVE / LOAD" 40 30 30 :green)
       (if (probe-file *default-save-path*)
           (raylib:draw-text "ENTER: Load saved game" 40 100 22 :white)
           (raylib:draw-text "No saved game found." 40 100 22 :gray))
       (raylib:draw-text "ESC: Back" 40 (- window-height 40) 18 :gray))
      (:playing
       (let ((game (arcade-state-current-game state)))
         (game-render game window-width window-height)
         (when (arcade-state-popup-open state)
           (draw-popup-menu state window-width window-height)))))))

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
