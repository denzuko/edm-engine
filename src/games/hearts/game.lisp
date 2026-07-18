(in-package :edm-engine/games/hearts)

(defstruct (hearts-game (:constructor %make-hearts-game))
  (hands nil :type list)
  (scores '(0 0 0 0) :type list)
  (round-points '(0 0 0 0) :type list)
  (current-trick nil :type list)
  (leader 0 :type fixnum)
  (turn 0 :type fixnum)
  (hearts-broken nil :type boolean)
  (round 1 :type fixnum)
  (phase :passing :type (member :passing :playing))
  (passed-cards nil :type list)
  (cursor 0 :type fixnum)
  (pass-selection nil :type list)
  (status :playing :type (member :playing :won :lost))
  (trick-pause-until 0.0d0 :type double-float)
  ;; #30's actual fix: *AI-DIFFICULTY* is only LET-bound for the
  ;; duration of the constructor call (ARCADE-CONFIRM-DIFFICULTY) —
  ;; captured here, at construction time, while it's still correctly
  ;; bound, rather than read later from the render layer where it's
  ;; already reverted to the global default. Interim fix, matching this
  ;; struct's existing shape — #39's SEAT/AI-CHARACTER redesign will
  ;; likely supersede this slot, not extend it; not blocking a real,
  ;; live bug on a much larger unimplemented design landing first.
  (ai-difficulty :novice :type (member :novice :standard :expert)))

(defun find-two-of-clubs-holder (hands)
  (position-if (lambda (hand) (member (cons 2 :clubs) hand :test #'equal)) hands))

(defun make-hearts-game (&key (seed (random 1000000)) (round 1) (scores '(0 0 0 0)))
  (let* ((hands (deal-hands (shuffled-deck seed)))
         (direction (pass-direction-for-round round))
         (phase (if (eq direction :none) :playing :passing))
         (game (%make-hearts-game :hands hands :round round :phase phase :scores scores
                                   :ai-difficulty edm-engine:*ai-difficulty*)))
    (when (eq phase :playing)
      (let ((leader (find-two-of-clubs-holder hands)))
        (setf (hearts-game-leader game) leader (hearts-game-turn game) leader)))
    game))

(defun play-card (game player card)
  "PLAYER plays CARD from their hand. Advances turn, or — once the
trick's 4th card lands — scores the trick to its winner, clears the
trick, and sets them as the next leader."
  (setf (nth player (hearts-game-hands game))
        (remove card (nth player (hearts-game-hands game)) :test #'equal :count 1))
  (setf (hearts-game-current-trick game) (append (hearts-game-current-trick game) (list card)))
  (when (eq (cdr card) :hearts) (setf (hearts-game-hearts-broken game) t))
  (if (= 4 (length (hearts-game-current-trick game)))
      (let* ((led-suit (cdr (first (hearts-game-current-trick game))))
             (winner-offset (trick-winner-index (hearts-game-current-trick game) led-suit))
             (winner (mod (+ (hearts-game-leader game) winner-offset) 4))
             (points (reduce #'+ (mapcar #'card-points (hearts-game-current-trick game)))))
        (setf (hearts-game-round-points game)
              (loop for i from 0 below 4
                    collect (+ (nth i (hearts-game-round-points game)) (if (= i winner) points 0))))
        (setf (hearts-game-current-trick game) nil
              (hearts-game-leader game) winner
              (hearts-game-turn game) winner))
      (setf (hearts-game-turn game) (mod (1+ player) 4)))
  game)

(defun pass-cards (game player cards)
  (setf (nth player (hearts-game-hands game))
        (set-difference (nth player (hearts-game-hands game)) cards :test #'equal))
  (setf (hearts-game-passed-cards game)
        (append (hearts-game-passed-cards game) (list (cons player cards)))))

(defun round-over-p (game)
  (every #'null (hearts-game-hands game)))

(declaim (ftype (function (list) boolean) shoot-the-moon-p))
(defun shoot-the-moon-p (round-points)
  (and (= 1 (count 26 round-points)) (every (lambda (p) (or (= p 26) (= p 0))) round-points)))

(defun score-round (game)
  (let ((rp (hearts-game-round-points game)))
    (setf (hearts-game-scores game)
          (if (shoot-the-moon-p rp)
              (let ((shooter (position 26 rp)))
                (loop for i from 0 below 4
                      collect (+ (nth i (hearts-game-scores game)) (if (= i shooter) 0 26))))
              (mapcar #'+ (hearts-game-scores game) rp)))))

(declaim (ftype (function (list) boolean) game-over-p))
(defun game-over-p (scores)
  (some (lambda (s) (>= s 100)) scores))

(defun target-player (player direction)
  (ecase direction
    (:left (mod (1+ player) 4))
    (:right (mod (1- player) 4))
    (:across (mod (+ player 2) 4))
    (:none player)))

(defun execute-pass (game)
  "All 4 players pass simultaneously — human's choice comes from
PASS-SELECTION, the other three from AI-CHOOSE-PASS — then transitions
to :PLAYING with the 2-of-clubs holder leading."
  (let* ((direction (pass-direction-for-round (hearts-game-round game)))
         (chosen (loop for p from 0 below 4
                       collect (if (= p 0)
                                   (hearts-game-pass-selection game)
                                   (ai-choose-pass (nth p (hearts-game-hands game)))))))
    (dotimes (p 4)
      (setf (nth p (hearts-game-hands game))
            (set-difference (nth p (hearts-game-hands game)) (nth p chosen) :test #'equal)))
    (dotimes (p 4)
      (let ((target (target-player p direction)))
        (setf (nth target (hearts-game-hands game))
              (append (nth target (hearts-game-hands game)) (nth p chosen)))))
    (setf (hearts-game-phase game) :playing
          (hearts-game-pass-selection game) nil
          (hearts-game-cursor game) 0)
    (let ((leader (find-two-of-clubs-holder (hearts-game-hands game))))
      (setf (hearts-game-leader game) leader (hearts-game-turn game) leader))))

(defun toggle-pass-selection (game card)
  (if (member card (hearts-game-pass-selection game) :test #'equal)
      (setf (hearts-game-pass-selection game)
            (remove card (hearts-game-pass-selection game) :test #'equal))
      (when (< (length (hearts-game-pass-selection game)) 3)
        (push card (hearts-game-pass-selection game)))))

(defun move-hand-cursor (game delta hand-length)
  (when (plusp hand-length)
    (setf (hearts-game-cursor game) (mod (+ (hearts-game-cursor game) delta) hand-length))))

(defun advance-round (game)
  "Deals a fresh round, carrying SCORES forward — called once the
previous round is scored and the game isn't over yet."
  (let ((next (make-hearts-game :round (1+ (hearts-game-round game))
                                 :scores (hearts-game-scores game))))
    (setf (hearts-game-hands game) (hearts-game-hands next)
          (hearts-game-round-points game) '(0 0 0 0)
          (hearts-game-current-trick game) nil
          (hearts-game-leader game) (hearts-game-leader next)
          (hearts-game-turn game) (hearts-game-turn next)
          (hearts-game-hearts-broken game) nil
          (hearts-game-round game) (hearts-game-round next)
          (hearts-game-phase game) (hearts-game-phase next)
          (hearts-game-passed-cards game) nil
          (hearts-game-cursor game) 0
          (hearts-game-pass-selection game) nil)))

(defmethod edm-engine:game-outcome ((game hearts-game))
  (case (hearts-game-status game)
    (:won :win)
    (:lost :lose)
    (t nil)))

(defmethod edm-engine:game-score ((game hearts-game))
  (max 0 (- 100 (first (hearts-game-scores game)))))

(defun ai-choose-play (hand led-suit hearts-broken)
  (let ((choices (legal-plays hand :led-suit led-suit :hearts-broken hearts-broken :leading-p (null led-suit))))
    (reduce (lambda (a b) (if (< (car a) (car b)) a b)) choices)))

(defun ai-choose-pass (hand)
  (subseq (sort (copy-list hand) #'> :key #'car) 0 3))
