(in-package :edm-engine/games/hearts)

(declaim (optimize (speed 3) (safety 3)))

;; #59's audio piece — was five direct, inline PLAY-TONE calls
;; scattered across GAME-UPDATE/MAYBE-RUN-AI-TURN, now declared as
;; data.
(edm-engine/audio:defaudio-cues :hearts
  (:ai-card-played :square 500.0 0.04)
  (:card-selected :square 500.0 0.03)
  (:pass-executed :sine 800.0 0.15)
  (:player-card-played :square 700.0 0.05)
  (:round-scored :sine 1000.0 0.3))

;;; CARD-STRING/CARD-COLOR/+CARD-WIDTH+/+CARD-HEIGHT+/DRAW-CARD-FACE/
;;; DRAW-CARD-BACK now live in EDM-ENGINE/CARDS — generic to any card
;;; game, not Hearts-specific. This file's own contribution is the
;;; Hearts-specific TABLE LAYOUT (where the trick/hands/passing UI sit),
;;; not the card silhouette itself.

(defvar *theme-sound* nil)
(defvar *ai-clock* (edm-engine:make-ai-timer))
(defvar *card-tweens* (make-hash-table :test #'equal)
  "CARD -> TWEEN, for the 'floating card easing into place' effect when
a card moves from a hand to the trick. Built on the shared
src/tween.lisp engine — the first real consumer, not a Hearts-specific
animation hack.")

(defparameter +tween-duration+ 0.55d0
  "Long enough to genuinely see the motion, not just technically animate
it — 0.35s round-tripped through video compression reads as an instant
cut more often than not, especially over a short start/end distance.")

(defun start-card-tween (card start-x start-y end-x end-y)
  (edm-engine/cards:start-card-tween *card-tweens* card start-x start-y end-x end-y
                                      (raylib:get-time) +tween-duration+))

(defun card-draw-position (card default-x default-y)
  "Returns (values x y) — the card's TWEENED position while its
animation is still running, or DEFAULT-X/Y once it's finished (or was
never tweened, e.g. a hand card that hasn't moved)."
  (edm-engine/cards:card-draw-position *card-tweens* card default-x default-y (raylib:get-time)))

;; #36's DEFLAYOUT retrofit — HAND-CARD-X was already an LRP call
;; (this session's own earlier retrofit); now declared as data rather
;; than a bare function body, the macro's own first real consumer.
(edm-engine:deflayout hand-card-x (i)
  (:row :anchor 20 :item-size 55 :gap 0 :index i))
(defun hand-card-y (window-height) (- window-height 90))

(defun trick-card-x (window-width i) (+ (/ window-width 2.0) (* i 55) -110))
(defun trick-card-y (window-height) (- (/ window-height 2.0) 31))

;; #36's DEFLAYOUT retrofit — was three direct ANCHOR-AT-EDGE calls;
;; now each declared as data via DEFLAYOUT itself.
(edm-engine:deflayout ai-origin-1 (window-width window-height)
  (:anchor :edge :left :offset 24.0 :container-w window-width :container-h window-height
           :content-w 0.0 :content-h 62.0))
(edm-engine:deflayout ai-origin-2 (window-width window-height)
  (:anchor :edge :top :offset 40.0 :container-w window-width :container-h window-height
           :content-w 46.0 :content-h 0.0))
(edm-engine:deflayout ai-origin-3 (window-width window-height)
  (:anchor :edge :right :offset 70.0 :container-w window-width :container-h window-height
           :content-w 0.0 :content-h 62.0))

(defun ai-origin-position (player window-width window-height)
  "Approximate screen position of PLAYER's card stack — cards fly FROM
here, not from an exact per-card hand layout (AI hands are shown as a
face-down stack, not individually laid out)."
  (ecase player
    (1 (ai-origin-1 window-width window-height))
    (2 (ai-origin-2 window-width window-height))
    (3 (ai-origin-3 window-width window-height))))

(defun ensure-theme-playing ()
  "#22: non-blocking. Lifted, generic implementation now in
EDM-ENGINE/AUDIO — this was found byte-for-byte duplicated across all
four games, only the theme-pattern/duration/topic varying."
  (setf *theme-sound*
        (edm-engine/audio:ensure-theme-playing
         *theme-sound* (hearts-theme-pattern) +hearts-theme-row-duration+
         edm-engine:*engine-bus* :hearts-theme)))

;; DRAW-AI-STACK now lives in EDM-ENGINE/CARDS/RENDER — generic to
;; any multi-seat card game's own opponent-hand display, not Hearts-
;; specific.

(defun draw-hearts-table (game window-width window-height)
  (let ((cy (/ window-height 2.0)))
    (raylib:draw-text (format nil "Round ~D   Scores: You ~D  AI-1 ~D  AI-2 ~D  AI-3 ~D"
                               (hearts-game-round game) (first (hearts-game-scores game))
                               (second (hearts-game-scores game)) (third (hearts-game-scores game))
                               (fourth (hearts-game-scores game)))
                       20 16 18 (edm-engine:rgb-color (edm-engine:theme-color :info)))
    (let ((glyph-color (edm-engine:rgb-color (edm-engine:resolve-style-role '(:hearts :ai-avatar) :glyph-color))))
      (edm-engine/cards:draw-ai-stack 24.0 (- cy 31.0) (length (second (hearts-game-hands game))) "AI-1" (hearts-game-ai-difficulty game) glyph-color)
      (edm-engine/cards:draw-ai-stack (- (/ window-width 2.0) 23.0) 40.0 (length (third (hearts-game-hands game))) "AI-2" (hearts-game-ai-difficulty game) glyph-color)
      (edm-engine/cards:draw-ai-stack (- window-width 70.0) (- cy 31.0) (length (fourth (hearts-game-hands game))) "AI-3" (hearts-game-ai-difficulty game) glyph-color))
    ;; current trick, centered — real card faces, tweened positions
    ;; while a card's animation is still running
    (loop for card in (hearts-game-current-trick game)
          for i from 0
          do (multiple-value-bind (x y)
                 (card-draw-position card (trick-card-x window-width i) (trick-card-y window-height))
               (draw-card-face x y card)))
    (if (eq (hearts-game-phase game) :passing)
        (draw-passing-ui game window-width window-height)
        (draw-human-hand game window-width window-height))))

(defun draw-passing-ui (game window-width window-height)
  (declare (ignore window-width))
  (let ((hand (first (hearts-game-hands game))))
    (raylib:draw-text (format nil "Pass 3 cards (~A): Enter to select/deselect, Enter again on the third to send"
                               (pass-direction-for-round (hearts-game-round game)))
                       20 (- window-height 130) 16 (edm-engine:rgb-color (edm-engine:theme-color :muted)))
    (edm-engine/cards:draw-card-hand
     (edm-engine/cards:make-card-hand-widget
      :cards hand :cursor-index (hearts-game-cursor game)
      :selected-cards (hearts-game-pass-selection game))
     #'hand-card-x (hand-card-y window-height))))

(defun draw-human-hand (game window-width window-height)
  (declare (ignore window-width))
  (let* ((hand (first (hearts-game-hands game)))
         (led-suit (when (hearts-game-current-trick game) (cdr (first (hearts-game-current-trick game)))))
         (legal (when (= 0 (hearts-game-turn game))
                  (legal-plays hand :led-suit led-suit :hearts-broken (hearts-game-hearts-broken game)
                                     :leading-p (null (hearts-game-current-trick game))))))
    (edm-engine/cards:draw-card-hand
     (edm-engine/cards:make-card-hand-widget
      :cards hand :cursor-index (hearts-game-cursor game) :legal-cards legal)
     #'hand-card-x (hand-card-y window-height))))

(defparameter +hearts-ai-think-seconds+ 0.8d0)

(defun maybe-run-ai-turn (game)
  "AI players act after a short pause (>= +HEARTS-AI-THINK-SECONDS+, via
the shared EDM-ENGINE:AI-TIMER) so a human can actually see what's
happening, not an instant flurry of plays. *AI-DIFFICULTY* is read here
so the difficulty-selection screen's choice reaches this game — the
actual DECISION logic below is still the one Novice-tier heuristic
regardless of tier; Standard/Expert distinct behavior is real future
work (see GH #3), not implemented yet. Not pretending otherwise."
  (when (and (/= (hearts-game-turn game) 0) (edm-engine:ai-ready-p *ai-clock* (raylib:get-time)))
    (let* ((p (hearts-game-turn game))
           (led-suit (when (hearts-game-current-trick game) (cdr (first (hearts-game-current-trick game)))))
           (card (ai-choose-play (nth p (hearts-game-hands game)) led-suit (hearts-game-hearts-broken game)))
           (trick-index (length (hearts-game-current-trick game))))
      (multiple-value-bind (sx sy) (ai-origin-position p 1024.0 768.0)
        (start-card-tween card sx sy (trick-card-x 1024.0 trick-index) (trick-card-y 768.0)))
      (play-card game p card)
      (when (null (hearts-game-current-trick game)) (clrhash *card-tweens*))
      (edm-engine:bus-push edm-engine:*engine-bus* :audio (list :game :hearts :cue :ai-card-played))
      (edm-engine:ai-timer-reset *ai-clock* (raylib:get-time) +hearts-ai-think-seconds+))))

(defmethod edm-engine:game-title ((game hearts-game)) "Hearts")

(defmethod edm-engine:game-update ((game hearts-game))
  (ensure-theme-playing)
  (case (hearts-game-status game)
    (:playing
     (case (hearts-game-phase game)
       (:passing
        (let ((hand (first (hearts-game-hands game))))
          (when (raylib:is-key-pressed :key-left) (move-hand-cursor game -1 (length hand)))
          (when (raylib:is-key-pressed :key-right) (move-hand-cursor game 1 (length hand)))
          (when (raylib:is-key-pressed :key-enter)
            (let ((card (nth (hearts-game-cursor game) hand)))
              (toggle-pass-selection game card)
              (edm-engine:bus-push edm-engine:*engine-bus* :audio (list :game :hearts :cue :card-selected))
              (try-hearts-game-pass-executed game)))))
       (:playing
        (if (= 0 (hearts-game-turn game))
            (let* ((hand (first (hearts-game-hands game)))
                   (led-suit (when (hearts-game-current-trick game) (cdr (first (hearts-game-current-trick game))))))
              (when (raylib:is-key-pressed :key-left) (move-hand-cursor game -1 (length hand)))
              (when (raylib:is-key-pressed :key-right) (move-hand-cursor game 1 (length hand)))
              (when (raylib:is-key-pressed :key-enter)
                (let* ((card (nth (hearts-game-cursor game) hand))
                       (legal (legal-plays hand :led-suit led-suit :hearts-broken (hearts-game-hearts-broken game)
                                                 :leading-p (null (hearts-game-current-trick game)))))
                  (when (member card legal :test #'equal)
                    (start-card-tween card (hand-card-x (hearts-game-cursor game)) (hand-card-y 768.0)
                                       (trick-card-x 1024.0 (length (hearts-game-current-trick game)))
                                       (trick-card-y 768.0))
                    (play-card game 0 card)
                    (when (null (hearts-game-current-trick game)) (clrhash *card-tweens*))
                    (setf (hearts-game-cursor game) 0)
                    (edm-engine:bus-push edm-engine:*engine-bus* :audio (list :game :hearts :cue :player-card-played))
                    (edm-engine:ai-timer-reset *ai-clock* (raylib:get-time) +hearts-ai-think-seconds+)))))
            (maybe-run-ai-turn game))
        (when (edm-engine:condition-true-p 'hearts-game 'round-over game)
          (score-round game)
          (edm-engine:bus-push edm-engine:*engine-bus* :audio (list :game :hearts :cue :round-scored))
          (cond
            ((edm-engine:condition-true-p 'hearts-game 'game-over game)
             (setf (hearts-game-status game)
                   (if (= (first (hearts-game-scores game)) (reduce #'min (hearts-game-scores game)))
                       :won :lost)))
            (t (advance-round game)))))))
    (t nil)))

(defmethod edm-engine:game-render ((game hearts-game) window-width window-height)
  (draw-hearts-table game window-width window-height))

(defmethod edm-engine:game-stop-audio ((game hearts-game))
  (declare (ignore game))
  (when *theme-sound* (raylib:stop-sound *theme-sound*)))

(edm-engine:register-game "Hearts" (lambda () (make-hearts-game)) :ai-capable-p t :restore-fn #'hearts-restore-game)
