(in-package :edm-engine/games/yahtzee)

(declaim (optimize (speed 3) (safety 3)))

;;; Dice as actual pip-faced squares — same lesson as Hearts' cards:
;;; a die shown as bare text ("3") reads as a terminal readout, not a
;;; die. Panel + border (matching the established card/chrome visual
;;; language) with real pip dots in the standard face arrangement.

(defparameter +die-size+ 60.0)

(defparameter +pip-layouts+
  '((1 . ((0.5 . 0.5)))
    (2 . ((0.25 . 0.25) (0.75 . 0.75)))
    (3 . ((0.25 . 0.25) (0.5 . 0.5) (0.75 . 0.75)))
    (4 . ((0.25 . 0.25) (0.75 . 0.25) (0.25 . 0.75) (0.75 . 0.75)))
    (5 . ((0.25 . 0.25) (0.75 . 0.25) (0.5 . 0.5) (0.25 . 0.75) (0.75 . 0.75)))
    (6 . ((0.25 . 0.2) (0.75 . 0.2) (0.25 . 0.5) (0.75 . 0.5) (0.25 . 0.8) (0.75 . 0.8))))
  "Fractional (x . y) pip positions within a die's bounding box, for
each face value 1-6 — the standard arrangement on a real die.")

(defun draw-die (x y value held-p cursor-p)
  (let ((rect (raylib:make-rectangle :x (float x 1.0) :y (float y 1.0) :width +die-size+ :height +die-size+)))
    (raylib:draw-rectangle-rounded rect 0.25 6
                                    (edm-engine:rgb-color (edm-engine:theme-color (if held-p :accent :panel)) (if held-p 60 255)))
    (raylib:draw-rectangle-rounded-lines rect 0.25 6 (if cursor-p 3.0 1.5)
                                          (edm-engine:rgb-color (edm-engine:theme-color (if cursor-p :accent :muted))))
    (dolist (pip (cdr (assoc value +pip-layouts+)))
      (raylib:draw-circle (round (+ x (* (car pip) +die-size+))) (round (+ y (* (cdr pip) +die-size+))) 4.5
                           (edm-engine:rgb-color (edm-engine:theme-color :info))))))

(defvar *theme-sound* nil)
(defvar *ai-clock* (edm-engine:make-ai-timer))
(defparameter +yahtzee-ai-think-seconds+ 0.9d0)

;;; #46's confetti — the arena's (#33) first real adoption, triggered
;;; on Yahtzee's win overlay (#34, the table this taxonomy entry names
;;; directly). A module-level arena/tick/prev-status, matching the
;;; existing *THEME-SOUND*/*AI-CLOCK* pattern for this file's own
;;; per-table state — not per-game-instance, since confetti is a
;;; presentation effect layered over whichever game instance is
;;; current, not game state itself.
(defvar *confettiArena* (edm-engine:make-arena 200))
(defvar *confettiTick* (edm-engine:make-tick))
(defvar *confettiPrevStatus* :playing)
(defparameter +confettiLifetime+ 3.0d0)

(defun ensure-theme-playing ()
  "#22: non-blocking — see Hearts' identical comment."
  (unless *theme-sound*
    (setf *theme-sound*
          (edm-engine/audio:ensure-theme-sound-async
           (yahtzee-theme-pattern) +yahtzee-theme-row-duration+
           edm-engine:*engine-bus* :yahtzee-theme :amplitude 0.3)))
  (when (and *theme-sound* (not (raylib:is-sound-playing *theme-sound*)))
    (raylib:play-sound *theme-sound*)))

(defun category-label (category)
  (case category
    (:ones "Ones") (:twos "Twos") (:threes "Threes") (:fours "Fours")
    (:fives "Fives") (:sixes "Sixes") (:three-of-a-kind "3 of a Kind")
    (:four-of-a-kind "4 of a Kind") (:full-house "Full House")
    (:small-straight "Sm. Straight") (:large-straight "Lg. Straight")
    (:yahtzee "Yahtzee") (:chance "Chance")))

(defun draw-scorecard (game window-height)
  (declare (ignore window-height))
  (let ((x 480) (y 90) (row-h 24))
    (loop for cat in +categories+
          for i from 0
          for filled = (getf (nth (yahtzee-game-turn game) (yahtzee-game-scores game)) cat)
          for selected-p = (= (+ i 5) (yahtzee-game-cursor game))
          do (raylib:draw-text (category-label cat) x (+ y (* i row-h)) 16
                                (cond (filled (edm-engine:rgb-color (edm-engine:theme-color :muted)))
                                      (selected-p (edm-engine:rgb-color (edm-engine:theme-color :accent)))
                                      (t (edm-engine:rgb-color (edm-engine:theme-color :info)))))
             (raylib:draw-text (if filled (format nil "~D" filled) "-")
                                (+ x 150) (+ y (* i row-h)) 16
                                (edm-engine:rgb-color (edm-engine:theme-color :muted))))))

(defun draw-yahtzee-table (game window-width window-height)
  (declare (ignore window-width))
  (raylib:draw-text (format nil "Player ~D of ~D   Rolls left: ~D"
                             (1+ (yahtzee-game-turn game)) (yahtzee-game-player-count game)
                             (yahtzee-game-rolls-remaining game))
                     20 16 18 (edm-engine:rgb-color (edm-engine:theme-color :info)))
  (when (/= 0 (yahtzee-game-turn game))
    (edm-engine:draw-glyph-text (cdr (assoc (yahtzee-game-ai-difficulty game) edm-engine:+ai-difficulty-glyphs+))
                                 320 8 26 (edm-engine:rgb-color (edm-engine:theme-color :info))))
  (let ((display-values (if (yahtzee-game-roll-animation game)
                             (edm-engine:roll-animation-display-values
                              (yahtzee-game-roll-animation game) (raylib:get-time) 6)
                             (yahtzee-game-dice game))))
    (loop for v in display-values
          for h in (yahtzee-game-held game)
          for i from 0
          do (draw-die (edm-engine:lrp 20 i 70 0) 90 v h (= i (yahtzee-game-cursor game)))))
  (draw-scorecard game window-height)
  (raylib:draw-text "Left/Right: dice | Enter: hold | Up: roll | Down: category list | Enter on category: score"
                     20 (- window-height 30) 12 (edm-engine:rgb-color (edm-engine:theme-color :muted))))

(defparameter +roll-animation-duration+ 0.4d0)

(defun start-roll-animation (game)
  (setf (yahtzee-game-roll-animation game)
        (edm-engine:make-roll-animation :start-time (raylib:get-time)
                                         :duration +roll-animation-duration+
                                         :final-values (yahtzee-game-dice game))))

(defmethod edm-engine:game-title ((game yahtzee-game)) "Yahtzee")

(defun maybe-run-ai-turn (game)
  (when (and (/= (yahtzee-game-turn game) 0) (edm-engine:ai-ready-p *ai-clock* (raylib:get-time)))
    (cond
      ((plusp (yahtzee-game-rolls-remaining game))
       (when (< (yahtzee-game-rolls-remaining game) 3)
         (setf (yahtzee-game-held game) (ai-choose-holds (yahtzee-game-dice game) (yahtzee-game-held game))))
       (roll-turn-dice game)
       (start-roll-animation game)
       (edm-engine/audio:play-tone :square 500.0 0.04))
      (t
       (let ((cat (ai-choose-category (yahtzee-game-dice game) (available-categories game (yahtzee-game-turn game)))))
         (commit-score game cat)
         (edm-engine/audio:play-tone :sine 700.0 0.15))))
    (edm-engine:ai-timer-reset *ai-clock* (raylib:get-time) +yahtzee-ai-think-seconds+)))

(defmethod edm-engine:game-update ((game yahtzee-game))
  (ensure-theme-playing)
  (case (yahtzee-game-status game)
    (:playing
     (if (= 0 (yahtzee-game-turn game))
         (let* ((available (available-categories game 0))
                (max-cursor (+ 4 (length +categories+))))
           (when (raylib:is-key-pressed :key-left)
             (setf (yahtzee-game-cursor game) (max 0 (1- (yahtzee-game-cursor game)))))
           (when (raylib:is-key-pressed :key-right)
             (setf (yahtzee-game-cursor game) (min max-cursor (1+ (yahtzee-game-cursor game)))))
           (when (raylib:is-key-pressed :key-up)
             (when (plusp (yahtzee-game-rolls-remaining game))
               (roll-turn-dice game)
               (start-roll-animation game)
               (edm-engine/audio:play-tone :square 500.0 0.05)))
           (when (raylib:is-key-pressed :key-enter)
             (cond
               ((< (yahtzee-game-cursor game) 5)
                (toggle-hold game (yahtzee-game-cursor game))
                (edm-engine/audio:play-tone :square 600.0 0.03))
               ((< (yahtzee-game-rolls-remaining game) 3)
                (let ((cat (nth (- (yahtzee-game-cursor game) 5) +categories+)))
                  (when (member cat available)
                    (commit-score game cat)
                    (edm-engine/audio:play-tone :sine 700.0 0.15)))))))
         (maybe-run-ai-turn game))
     (when (game-over-p game)
       (edm-engine/audio:play-tone :sine 1000.0 0.3)
       (setf (yahtzee-game-status game)
             (if (= 0 (winner-index game)) :won :lost))))
    (t nil)))

(defmethod edm-engine:game-render ((game yahtzee-game) window-width window-height)
  (draw-yahtzee-table game window-width window-height))

(defmethod edm-engine:gameOverlayEffects ((game yahtzee-game) window-width window-height)
  ;; #46's confetti, #33's arena's first real adoption — a status
  ;; transition INTO :won specifically (not every frame while already
  ;; :won) is the trigger, matching how a real celebration moment
  ;; should fire once, not continuously.
  ;;
  ;; Lives in GAMEOVERLAYEFFECTS, not GAME-RENDER, for a real reason
  ;; found and fixed during live verification, not assumed correct at
  ;; write time: #54's own fix made the outcome popup fully opaque,
  ;; and that popup opens the same frame a win is detected — so
  ;; anything drawn inside GAME-RENDER (which runs BEFORE the popup in
  ;; ARCADE-RENDER's own flow) gets immediately painted over by it,
  ;; regardless of draw order within GAME-RENDER itself. A pixel-level
  ;; check (zero moving teal pixels between consecutive frames, despite
  ;; the arena correctly holding 80 live particles) is what actually
  ;; caught this, not visual inspection alone. GAMEOVERLAYEFFECTS runs
  ;; after the popup in ARCADE-RENDER, a true top layer.
  (when (and (eq (yahtzee-game-status game) :won) (not (eq *confettiPrevStatus* :won)))
    (edm-engine:spawnConfetti *confettiArena* (/ window-width 2.0) (/ window-height 3.0) 80
                               (raylib:get-time) (make-random-state t) :speed-range 180.0))
  (setf *confettiPrevStatus* (yahtzee-game-status game))
  (edm-engine:advance-tick *confettiArena* *confettiTick* (raylib:get-frame-time))
  (edm-engine:despawnExpired *confettiArena* (raylib:get-time) +confettiLifetime+)
  (dolist (h (edm-engine:arena-live-handles *confettiArena*))
    (multiple-value-bind (x y) (edm-engine:arena-position *confettiArena* h)
      (raylib:draw-circle (round x) (round y) 4.0 (edm-engine:rgb-color (edm-engine:theme-color :accent))))))

(defmethod edm-engine:game-stop-audio ((game yahtzee-game))
  (declare (ignore game))
  (when *theme-sound* (raylib:stop-sound *theme-sound*)))

(edm-engine:register-game "Yahtzee" (lambda () (make-yahtzee-game)) :ai-capable-p t)
