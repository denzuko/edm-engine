(in-package :edm-engine)


(declaim (ftype (function (list &optional (unsigned-byte 8)) (unsigned-byte 32)) rgb-float->hex))
(defun rgb-float->hex (triple &optional (alpha 255))
  (destructuring-bind (r g b) triple
    (logior (ash (round (* r 255)) 24) (ash (round (* g 255)) 16) (ash (round (* b 255)) 8) alpha)))

(defun rgb-color (triple &optional (alpha 255))
  "Converts one of src/palette.lisp's 0.0-1.0 float triples into a
raylib color — the same tokens the tile shader uses, applied to the
chrome (menus, backgrounds) so the whole arcade shares one palette."
  (raylib:get-color (rgb-float->hex triple alpha)))

(defun menu-item-color (selected-p)
  "Accent when SELECTED-P, muted otherwise — this exact
selected/unselected branch was duplicated across the main menu and
the tables list."
  (rgb-color (theme-color (if selected-p :accent :muted))))

(defvar *title-theme-sound* nil)
(defun ensure-title-theme-playing ()
  "#22: non-blocking — see Hearts' identical comment. The title screen
is the very first thing every player sees; a 44ms synchronous hitch
here was the worst possible place for it, not just an inconvenience on
some other table."
  (unless *title-theme-sound*
    (setf *title-theme-sound*
          (edm-engine/audio:ensure-theme-sound-async
           (title-theme-pattern) +title-theme-row-duration+
           *engine-bus* :title-theme :amplitude 0.3)))
  (when (and *title-theme-sound* (not (raylib:is-sound-playing *title-theme-sound*)))
    (raylib:play-sound *title-theme-sound*)))

(defun draw-section-title (text)
  (raylib:draw-text text 40 30 30 (rgb-color (theme-color :accent))))

(defun draw-back-hint (window-height)
  (raylib:draw-text "ESC: Back" 40 (- window-height 40) 18 (rgb-color (theme-color :muted))))

(defvar *save-slot-preview-texture* nil)
(defvar *save-slot-preview-slot* nil)

(defun save-slot-preview-texture (slot)
  "Loads SLOT's screenshot as a texture, cached — reloaded only when the
browsed slot actually changes, not every frame. Full resolution; scaled
down at DRAW time via DRAW-TEXTURE-PRO's source/dest rectangle mismatch
rather than resizing the image itself (CL-RAYLIB:IMAGE-RESIZE wants a
:POINTER, but LOAD-IMAGE returns the struct by value — the mismatch
isn't worth chasing for a thumbnail)."
  (unless (eql *save-slot-preview-slot* slot)
    (when *save-slot-preview-texture* (raylib:unload-texture *save-slot-preview-texture*))
    (setf *save-slot-preview-slot* slot)
    (setf *save-slot-preview-texture*
          (let ((path (save-slot-screenshot-path slot)))
            (when (probe-file path)
              (raylib:load-texture (namestring path))))))
  *save-slot-preview-texture*)

(defun arcade-update (state)
  (ecase (arcade-state-mode state)
    (:title
     (ensure-title-theme-playing)
     (when (or (raylib:is-key-pressed :key-enter) (raylib:is-key-pressed :key-space))
       (when *title-theme-sound* (raylib:stop-sound *title-theme-sound*))
       (arcade-dismiss-title state)))
    (:main-menu
     (when (raylib:is-key-pressed :key-down) (arcade-select-next-main-menu state))
     (when (raylib:is-key-pressed :key-up) (arcade-select-previous-main-menu state))
     (when (raylib:is-key-pressed :key-enter) (arcade-drill-into-main-menu-selection state)))
    (:tables
     (when (raylib:is-key-pressed :key-down) (arcade-select-next-table state))
     (when (raylib:is-key-pressed :key-up) (arcade-select-previous-table state))
     (when (raylib:is-key-pressed :key-enter) (arcade-launch-selected state))
     (when (raylib:is-key-pressed :key-escape) (arcade-back-to-main-menu state)))
    (:difficulty
     (when (raylib:is-key-pressed :key-right) (arcade-select-next-difficulty state))
     (when (raylib:is-key-pressed :key-left) (arcade-select-previous-difficulty state))
     (when (raylib:is-key-pressed :key-enter) (arcade-confirm-difficulty state))
     (when (raylib:is-key-pressed :key-escape)
       (setf (arcade-state-pending-entry state) nil (arcade-state-mode state) :tables)))
    (:options
     (when (raylib:is-key-pressed :key-down) (arcade-select-next-option-row state))
     (when (raylib:is-key-pressed :key-up) (arcade-select-previous-option-row state))
     (when (= 0 (arcade-state-options-cursor state))
       (when (raylib:is-key-pressed :key-right)
         (arcade-increase-volume state)
         (edm-engine/audio:ensure-audio-device)
         (raylib:set-master-volume (arcade-state-volume state)))
       (when (raylib:is-key-pressed :key-left)
         (arcade-decrease-volume state)
         (edm-engine/audio:ensure-audio-device)
         (raylib:set-master-volume (arcade-state-volume state))))
     (when (= 1 (arcade-state-options-cursor state))
       (when (or (raylib:is-key-pressed :key-left) (raylib:is-key-pressed :key-right)
                 (raylib:is-key-pressed :key-enter))
         (arcade-toggle-theme-direction state)))
     (when (= 2 (arcade-state-options-cursor state))
       (when (or (raylib:is-key-pressed :key-left) (raylib:is-key-pressed :key-right)
                 (raylib:is-key-pressed :key-enter))
         (toggle-render-mode)))
     (when (raylib:is-key-pressed :key-escape) (arcade-back-to-main-menu state)))
    (:save-load
     (when (raylib:is-key-pressed :key-down) (arcade-select-next-save-slot state))
     (when (raylib:is-key-pressed :key-up) (arcade-select-previous-save-slot state))
     (when (raylib:is-key-pressed :key-enter) (arcade-load-selected-save-slot state))
     (when (raylib:is-key-pressed :key-escape) (arcade-back-to-main-menu state)))
    (:playing
     (let ((game (arcade-state-current-game state)))
       (cond
         ((arcade-state-popup-open state)
          (when (raylib:is-key-pressed :key-down) (arcade-popup-next state))
          (when (raylib:is-key-pressed :key-up) (arcade-popup-previous state))
          (when (raylib:is-key-pressed :key-enter)
            (let* ((selected (nth (arcade-state-popup-index state) (arcade-popup-items game)))
                   (slot (arcade-state-save-slot-index state)))
              (when (or (string= selected "New Game") (string= selected "Return to Tables"))
                (edm-engine:game-stop-audio game))
              (arcade-popup-confirm state)
              (when (string= selected "Save State")
                ;; raylib:take-screenshot always joins its path onto the
                ;; process's CWD, even for an already-absolute path — so
                ;; screenshot to a plain relative name, then move it with
                ;; plain Lisp file I/O, which has no such quirk.
                (raylib:take-screenshot "parencade-save-thumbnail-tmp.png")
                (ensure-save-directory)
                (uiop:rename-file-overwriting-target
                 "parencade-save-thumbnail-tmp.png"
                 (save-slot-screenshot-path slot))))))
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
    ;; #54: was alpha 200 (semi-transparent) — the underlying table's
    ;; content (scorecard text, dice, cards) bled through visibly
    ;; behind the popup's own text, reported directly as "all elements
    ;; overlaying at once." Fully opaque now — readability over a
    ;; subtle see-through-backdrop effect when the two conflict.
    (raylib:draw-rectangle 0 0 window-width window-height (rgb-color (theme-color :panel) 255))
    (when outcome
      (let* ((label (ecase outcome (:win "YOU WON") (:lose "YOU LOST") (:tie "TIE GAME")))
             (tw (raylib:measure-text label 44)))
        (raylib:draw-text label (round (/ (- window-width tw) 2)) 140 44 (rgb-color (theme-color :accent)))))
    (loop for item in items
          for i from 0
          for y = (+ 260 (* i 40))
          do (raylib:draw-text item (round (- (/ window-width 2) 90)) y 28
                                (menu-item-color (= i (arcade-state-popup-index state)))))))

(defun arcade-render (state window-width window-height)
  "One BeginDrawing/EndDrawing per frame, established here — GAME-RENDER
methods (e.g. DRAW-GRID) assume they're already inside a drawing context
and never call WITH-DRAWING themselves. The background is drawn via the
chrome shader (genuinely GPU HSV-driven per-role, from unifiedspec.org's
actual tokens — see src/palette.lisp), not a flat CLEAR-BACKGROUND."
  (raylib:with-drawing
    (raylib:clear-background
     (if (and (eq *render-mode* :cpu) (eq *theme-direction* :dark)) :black :white))
    (draw-chrome-rect 0 0 window-width window-height :dim)
    (raylib:draw-rectangle-lines-ex
     (raylib:make-rectangle :x 2.0 :y 2.0 :width (float (- window-width 4) 1.0) :height (float (- window-height 4) 1.0))
     3.0 (rgb-color (theme-color :accent)))
    (ecase (arcade-state-mode state)
      (:title
       (let* ((name-size 72)
              (name-w (ui-text-width +engine-name+ name-size))
              (tagline "TABLE GAMES COLLECTION")
              (tagline-w (glyph-text-width tagline 20))
              (prompt "PRESS ENTER")
              (prompt-w (glyph-text-width prompt 18))
              (pulse (+ 0.5 (* 0.5 (sin (* 3.0 (raylib:get-time)))))))
         (draw-ui-text +engine-name+ (round (/ (- window-width name-w) 2.0)) 230 name-size
                        (rgb-color (theme-color :accent)))
         (draw-glyph-text tagline (round (/ (- window-width tagline-w) 2.0)) (+ 230 name-size +space-3+) 20
                           (rgb-color (theme-color :info)))
         (draw-glyph-text prompt (round (/ (- window-width prompt-w) 2.0)) (- window-height +space-8+) 18
                           (rgb-color (theme-color :accent) (round (* 255 pulse))))
         (draw-glyph-text "A DPS Production" +space-5+ (- window-height +space-6+) 14
                           (rgb-color (theme-color :muted)))))
      (:main-menu
       (draw-ui-text +engine-name+ +space-6+ +space-5+ 34 (rgb-color (theme-color :accent)))
       (draw-ui-text (format nil "Score: ~D" (arcade-state-total-score state))
                      +space-6+ (- window-height +space-6+) 18 (rgb-color (theme-color :muted)))
       (loop for item in +main-menu-items+
             for i from 0
             do (draw-ui-text item +space-6+ (+ 100 (* i 40)) 26
                               (menu-item-color (= i (arcade-state-main-menu-index state))))))
      (:tables
       (draw-section-title "TABLES")
       (loop for entry in *games*
             for i from 0
             do (raylib:draw-text (game-entry-title entry) 40 (+ 90 (* i 36)) 26
                                   (menu-item-color (= i (arcade-state-table-index state)))))
       (draw-back-hint window-height))
      (:difficulty
       (draw-section-title (format nil "~A: CHOOSE OPPONENT SKILL"
                                    (game-entry-title (arcade-state-pending-entry state))))
       (let* ((card-w 180) (card-h 200) (gap 30) (y 130)
              (xs (centered-row-positions 3 card-w gap window-width)))
         (loop for tier in +ai-difficulty-tiers+
               for x in xs
               for i from 0
               for selected-p = (= i (arcade-state-difficulty-index state))
               do (draw-chrome-rect x y card-w card-h
                                     (resolve-style-role-keyword
                                      (if selected-p '(:difficulty :card-selected) '(:difficulty :card))
                                      :fill)
                                     (if selected-p 0.35 1.0))
                  (raylib:draw-rectangle-lines-ex
                   (raylib:make-rectangle :x (float x 1.0) :y (float y 1.0) :width (float card-w 1.0) :height (float card-h 1.0))
                   (if selected-p 3.0 1.0)
                   (rgb-color (theme-color (if selected-p :accent :muted))))
                  (draw-glyph-text (cdr (assoc tier +ai-difficulty-glyphs+ :test #'eq)) (+ x 60) (+ y 30) 60
                                    (rgb-color (theme-color (if selected-p :accent :info))))
                  (raylib:draw-text (ai-difficulty-label tier) (+ x 20) (+ y 120) 24
                                     (menu-item-color selected-p))
                  (draw-wrapped-text (cdr (assoc tier +ai-difficulty-descriptions+ :test #'eq))
                                      (+ x 12) (+ y 155) (- card-w 24) 12 (rgb-color (theme-color :muted)))))
       (draw-back-hint window-height))
      (:options
       (draw-section-title "ENGINE OPTIONS")
       (draw-ui-text (format nil "Master Volume: ~D%" (round (* 100 (arcade-state-volume state))))
                      40 100 22 (menu-item-color (= 0 (arcade-state-options-cursor state))))
       (draw-ui-text (format nil "Theme: ~A" (if (eq *theme-direction* :light) "Light" "Dark"))
                      40 140 22 (menu-item-color (= 1 (arcade-state-options-cursor state))))
       (draw-ui-text (format nil "Graphics: ~A" (if (eq *render-mode* :gpu) "Full (GPU)" "Simple (CPU)"))
                      40 180 22 (menu-item-color (= 2 (arcade-state-options-cursor state))))
       (draw-glyph-text "UP/DOWN: choose  LEFT/RIGHT: adjust" 40 220 16 (rgb-color (theme-color :muted)))
       (draw-back-hint window-height))
      (:save-load
       (draw-section-title "SAVE / LOAD")
       (let ((slots (list-save-slots)))
         (loop for i from 0 below *save-slot-count*
               for entry = (nth i slots)
               for y = (+ 80 (* i 22))
               do (raylib:draw-text
                   (if entry
                       (format nil "Slot ~D: ~A  score ~D  ~A" i (getf entry :table-title)
                               (getf entry :score) (format-save-timestamp (getf entry :timestamp)))
                       (format nil "Slot ~D: empty" i))
                   40 y 18 (menu-item-color (= i (arcade-state-save-slot-index state))))))
       ;; Thumbnail preview — screenshots ARE correctly captured and
       ;; stored (SAVE-SLOT-SCREENSHOT-PATH), and SAVE-SLOT-PREVIEW-
       ;; TEXTURE already handles loading/caching one correctly; the
       ;; real, actual gap was DRAW-TEXTURE-PRO's own call, previously
       ;; attempted with RAYLIB:MAKE-VECTOR2/RAYLIB:MAKE-COLOR — neither
       ;; function exists in this cl-raylib version at all (confirmed
       ;; directly, not assumed), which is what the prior "CFFI struct-
       ;; marshalling" diagnosis was actually hitting, not a real
       ;; binding incompatibility. 3D-VECTORS:VEC2 and RAYLIB:GET-COLOR
       ;; are this codebase's own, already-established constructors for
       ;; exactly these types (DRAW-TEXT-EX, RGB-COLOR above) — using
       ;; them here instead, live-verified working before landing.
       (let ((tex (save-slot-preview-texture (arcade-state-save-slot-index state))))
         (when tex
           (raylib:draw-texture-pro
            tex
            (raylib:make-rectangle :x 0.0 :y 0.0
                                    :width (float (raylib:texture-width tex) 1.0)
                                    :height (float (raylib:texture-height tex) 1.0))
            (raylib:make-rectangle :x 620.0 :y 80.0 :width 280.0 :height 210.0)
            (3d-vectors:vec2 0.0 0.0)
            0.0
            (raylib:get-color #xFFFFFFFF))))
       (draw-back-hint window-height))
      (:playing
       (let ((game (arcade-state-current-game state)))
         (game-render game window-width window-height)
         (when (arcade-state-popup-open state)
           (draw-popup-menu state window-width window-height))
         (gameOverlayEffects game window-width window-height))))))

(defvar *debug-arcade-state* nil
  "The live ARCADE-STATE, exposed for SWANK inspection when
EDM_ENGINE_SWANK_PORT is set — read-only from another thread (GL calls
from a non-main thread are unsafe; don't draw with this, just inspect).")

(defparameter *max-crashes-per-session* 20
  "A safeguard against an infinite crash-loop: if the SAME class of bug
fires every single frame (e.g. a bug in a table's GAME-RENDER that
reproduces even against a freshly-reset ARCADE-STATE), resetting state
and continuing wouldn't actually recover anything — it would spam the
crash log at up to 60 times a second and never surface the problem to
the player. Past this many crashes in one session, MAIN exits with a
clear message instead of continuing to loop.")

(defun main (&rest argv)
  "Boots the arcade: a main menu (Tables / Engine Options / Save-Load)
over every REGISTER-GAME entry, dispatching to the selected table's
GAME-UPDATE/GAME-RENDER each frame. This file has no knowledge of any
specific table — that's the whole point."
  (declare (ignore argv))
  (installGcHook)
  (let ((swank-port (sb-ext:posix-getenv "EDM_ENGINE_SWANK_PORT")))
    (when swank-port
      (swank:create-server :port (parse-integer swank-port) :dont-close t :style :spawn)))
  ;; #51/#50: named startup phases, not one undifferentiated cost —
  ;; the exact "first few cycles" breakdown #50's investigation needs,
  ;; now standing metrics instead of ad hoc measurement.
  (wTmr "startup.window_creation"
    (open-window (format nil "~A" +engine-name+) 1024 768))
  (unwind-protect
       (let ((state (wTmr "startup.arcade_state_init" (make-arcade-state)))
             (crash-count 0))
         (setf *debug-arcade-state* state)
         (loop until (window-should-close-p)
               do (handler-case
                      (wTmr "render.frame_time"
                        (arcade-update state)
                        (arcade-render state 1024 768))
                    (error (c)
                      (log-crash c)
                      (incf crash-count)
                      (when (> crash-count *max-crashes-per-session*)
                        (format *error-output*
                                "~&PARENCADE: too many errors this session (see ~A) — exiting rather than loop indefinitely.~%"
                                *crash-log-path*)
                        (return))
                      ;; a bug anywhere in any table's GAME-UPDATE/
                      ;; GAME-RENDER should never take down the whole
                      ;; session — recover to a fresh, known-good state
                      ;; (not attempt to salvage the one that just
                      ;; errored, which could be partially mutated) and
                      ;; keep playing, rather than crash to desktop with
                      ;; total progress loss.
                      (setf state (make-arcade-state))
                      (setf *debug-arcade-state* state)))))
    (close-window))
  (uiop:quit 0))
