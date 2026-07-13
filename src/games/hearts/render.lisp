(in-package :edm-engine/games/hearts)

(declaim (optimize (speed 3) (safety 3)))

;;; CARD-STRING/CARD-COLOR/+CARD-WIDTH+/+CARD-HEIGHT+/DRAW-CARD-FACE/
;;; DRAW-CARD-BACK now live in EDM-ENGINE/CARDS — generic to any card
;;; game, not Hearts-specific. This file's own contribution is the
;;; Hearts-specific TABLE LAYOUT (where the trick/hands/passing UI sit),
;;; not the card silhouette itself.

(defvar *theme-sound* nil)
(defvar *ai-next-action-time* 0.0d0)
(defvar *card-tweens* (make-hash-table :test #'equal)
  "CARD -> TWEEN, for the 'floating card easing into place' effect when
a card moves from a hand to the trick. Built on the shared
src/tween.lisp engine — the first real consumer, not a Hearts-specific
animation hack.")

(defparameter +tween-duration+ 0.55
  "Long enough to genuinely see the motion, not just technically animate
it — 0.35s round-tripped through video compression reads as an instant
cut more often than not, especially over a short start/end distance.")

(defun start-card-tween (card start-x start-y end-x end-y)
  (setf (gethash card *card-tweens*)
        (edm-engine:make-tween :start-x (float start-x 1.0) :start-y (float start-y 1.0)
                                :end-x (float end-x 1.0) :end-y (float end-y 1.0)
                                :start-time (raylib:get-time) :duration +tween-duration+)))

(defun card-draw-position (card default-x default-y)
  "Returns (values x y) — the card's TWEENED position while its
animation is still running, or DEFAULT-X/Y once it's finished (or was
never tweened, e.g. a hand card that hasn't moved)."
  (let ((tw (gethash card *card-tweens*)))
    (if (and tw (not (edm-engine:tween-finished-p tw (raylib:get-time))))
        (edm-engine:tween-position tw (raylib:get-time))
        (values (float default-x 1.0) (float default-y 1.0)))))

(defun hand-card-x (i) (+ 20 (* i 55)))
(defun hand-card-y (window-height) (- window-height 90))

(defun trick-card-x (window-width i) (+ (/ window-width 2.0) (* i 55) -110))
(defun trick-card-y (window-height) (- (/ window-height 2.0) 31))

(defun ai-origin-position (player window-width window-height)
  "Approximate screen position of PLAYER's card stack — cards fly FROM
here, not from an exact per-card hand layout (AI hands are shown as a
face-down stack, not individually laid out)."
  (ecase player
    (1 (values 24.0 (- (/ window-height 2.0) 31.0)))
    (2 (values (- (/ window-width 2.0) 23.0) 40.0))
    (3 (values (- window-width 70.0) (- (/ window-height 2.0) 31.0)))))

(defun ensure-theme-playing ()
  (unless *theme-sound*
    (setf *theme-sound*
          (edm-engine/audio:pattern-sound (hearts-theme-pattern) +hearts-theme-row-duration+
                                           :amplitude 0.3)))
  (unless (raylib:is-sound-playing *theme-sound*)
    (raylib:play-sound *theme-sound*)))

(defun draw-ai-stack (x y count label)
  "A small fanned stack of face-down cards standing in for an AI's
hand, plus a card-count label — not just 'AI-1: 13 cards' as bare text."
  (dotimes (i (min 4 (ceiling count 4)))
    (draw-card-back (+ x (* i 4)) (+ y (* i 3))))
  (raylib:draw-text (format nil "~A (~D)" label count) (round x) (round (+ y +card-height+ 8)) 14
                     (edm-engine:rgb-color (edm-engine:theme-color :muted))))

(defun draw-hearts-table (game window-width window-height)
  (let ((cy (/ window-height 2.0)))
    (raylib:draw-text (format nil "Round ~D   Scores: You ~D  AI-1 ~D  AI-2 ~D  AI-3 ~D"
                               (hearts-game-round game) (first (hearts-game-scores game))
                               (second (hearts-game-scores game)) (third (hearts-game-scores game))
                               (fourth (hearts-game-scores game)))
                       20 16 18 :white)
    (draw-ai-stack 24.0 (- cy 31.0) (length (second (hearts-game-hands game))) "AI-1")
    (draw-ai-stack (- (/ window-width 2.0) 23.0) 40.0 (length (third (hearts-game-hands game))) "AI-2")
    (draw-ai-stack (- window-width 70.0) (- cy 31.0) (length (fourth (hearts-game-hands game))) "AI-3")
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
    (loop for card in hand
          for i from 0
          for x = (hand-card-x i)
          for selected = (member card (hearts-game-pass-selection game) :test #'equal)
          do (draw-card-face x (hand-card-y window-height) card
                              :highlight-p (= i (hearts-game-cursor game))
                              :selected-p selected))))

(defun draw-human-hand (game window-width window-height)
  (declare (ignore window-width))
  (let* ((hand (first (hearts-game-hands game)))
         (led-suit (when (hearts-game-current-trick game) (cdr (first (hearts-game-current-trick game)))))
         (legal (when (= 0 (hearts-game-turn game))
                  (legal-plays hand :led-suit led-suit :hearts-broken (hearts-game-hearts-broken game)
                                     :leading-p (null (hearts-game-current-trick game))))))
    (loop for card in hand
          for i from 0
          for x = (hand-card-x i)
          for playable = (member card legal :test #'equal)
          do (draw-card-face x (hand-card-y window-height) card
                              :highlight-p (= i (hearts-game-cursor game))
                              :alpha (if (or (null legal) playable) 1.0 0.35)))))

(defun maybe-run-ai-turn (game)
  "AI players act after a short pause (>= +hearts-ai-think-seconds+) so a
human can actually see what's happening, not an instant flurry of plays."
  (when (and (/= (hearts-game-turn game) 0) (>= (raylib:get-time) *ai-next-action-time*))
    (let* ((p (hearts-game-turn game))
           (led-suit (when (hearts-game-current-trick game) (cdr (first (hearts-game-current-trick game)))))
           (card (ai-choose-play (nth p (hearts-game-hands game)) led-suit (hearts-game-hearts-broken game)))
           (trick-index (length (hearts-game-current-trick game))))
      (multiple-value-bind (sx sy) (ai-origin-position p 800.0 700.0)
        (start-card-tween card sx sy (trick-card-x 800.0 trick-index) (trick-card-y 700.0)))
      (play-card game p card)
      (when (null (hearts-game-current-trick game)) (clrhash *card-tweens*))
      (edm-engine/audio:play-tone :square 500.0 0.04)
      (setf *ai-next-action-time* (+ (raylib:get-time) 0.8)))))

(defparameter +hearts-ai-think-seconds+ 0.8)

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
              (edm-engine/audio:play-tone :square 500.0 0.03)
              (when (= 3 (length (hearts-game-pass-selection game)))
                (execute-pass game)
                (edm-engine/audio:play-tone :sine 800.0 0.15))))))
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
                    (start-card-tween card (hand-card-x (hearts-game-cursor game)) (hand-card-y 700.0)
                                       (trick-card-x 800.0 (length (hearts-game-current-trick game)))
                                       (trick-card-y 700.0))
                    (play-card game 0 card)
                    (when (null (hearts-game-current-trick game)) (clrhash *card-tweens*))
                    (setf (hearts-game-cursor game) 0)
                    (edm-engine/audio:play-tone :square 700.0 0.05)
                    (setf *ai-next-action-time* (+ (raylib:get-time) 0.8))))))
            (maybe-run-ai-turn game))
        (when (round-over-p game)
          (score-round game)
          (edm-engine/audio:play-tone :sine 1000.0 0.3)
          (cond
            ((game-over-p (hearts-game-scores game))
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

(edm-engine:register-game "Hearts" (lambda () (make-hearts-game)))
