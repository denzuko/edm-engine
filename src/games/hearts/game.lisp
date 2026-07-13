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
  (passed-cards nil :type list))

(defun find-two-of-clubs-holder (hands)
  (position-if (lambda (hand) (member (cons 2 :clubs) hand :test #'equal)) hands))

(defun make-hearts-game (&key (seed (random 1000000)) (round 1) (scores '(0 0 0 0)))
  (let* ((hands (deal-hands (shuffled-deck seed)))
         (direction (pass-direction-for-round round))
         (phase (if (eq direction :none) :playing :passing))
         (game (%make-hearts-game :hands hands :round round :phase phase :scores scores)))
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

;;; Simple heuristic AI — lowest legal card when playing, highest-ranked
;;; cards (the most dangerous to hold) when passing.

(defun ai-choose-play (hand led-suit hearts-broken)
  (let ((choices (legal-plays hand :led-suit led-suit :hearts-broken hearts-broken :leading-p (null led-suit))))
    (reduce (lambda (a b) (if (< (car a) (car b)) a b)) choices)))

(defun ai-choose-pass (hand)
  (subseq (sort (copy-list hand) #'> :key #'car) 0 3))
