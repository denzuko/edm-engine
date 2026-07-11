(in-package :edm-engine/games/wordle)

(declaim (optimize (speed 3) (safety 3)))

(defstruct (wordle-game (:constructor %make-wordle-game))
  (answer "" :type string)
  (history nil :type list)
  (max-rows 6 :type fixnum)
  (status :playing :type (member :playing :won :lost))
  (input (make-array 0 :element-type 'character :adjustable t :fill-pointer 0)))

(declaim (ftype (function (string &key (:max-rows fixnum)) wordle-game) make-wordle-game))
(defun make-wordle-game (answer &key (max-rows 6))
  (%make-wordle-game :answer (string-upcase answer) :max-rows max-rows))

(declaim (ftype (function (wordle-game string) wordle-game) submit-guess))
(defun submit-guess (game guess)
  "Appends GUESS's feedback to GAME's history and updates GAME's status.
Signals an error if GAME already finished, or GUESS isn't the right
length — this is the local BDD/e2e gate the CI pipeline doesn't need to
re-check."
  (unless (eq (wordle-game-status game) :playing)
    (error "wordle-game already finished: ~A" (wordle-game-status game)))
  (unless (= (length guess) (length (wordle-game-answer game)))
    (error "guess ~S must be ~D letters" guess (length (wordle-game-answer game))))
  (let* ((guess (string-upcase guess))
         (feedback (evaluate-guess guess (wordle-game-answer game))))
    (setf (wordle-game-history game)
          (append (wordle-game-history game) (list (cons guess feedback))))
    (cond ((string= guess (wordle-game-answer game))
           (setf (wordle-game-status game) :won))
          ((>= (length (wordle-game-history game)) (wordle-game-max-rows game))
           (setf (wordle-game-status game) :lost))))
  game)

(declaim (ftype (function (wordle-game) list) rows-for-render))
(defun rows-for-render (game)
  "Converts GAME's history into DRAW-GRID's row format: MAX-ROWS rows,
each a list of (LETTER . STATE) cells, padded with NIL rows for
unplayed guesses."
  (let ((played (mapcar (lambda (entry)
                           (loop for ch across (car entry)
                                 for st across (cdr entry)
                                 collect (cons ch st)))
                         (wordle-game-history game))))
    (append played
            (make-list (- (wordle-game-max-rows game) (length played))
                       :initial-element nil))))

(defun push-letter (game ch)
  "Appends CH (uppercased) to GAME's in-progress input, if GAME is
still playable, CH is a letter, and there's room for it."
  (when (and (eq (wordle-game-status game) :playing)
             (alpha-char-p ch)
             (< (fill-pointer (wordle-game-input game)) (length (wordle-game-answer game))))
    (vector-push-extend (char-upcase ch) (wordle-game-input game)))
  game)

(defun pop-letter (game)
  "Removes the last typed letter, if any."
  (when (plusp (fill-pointer (wordle-game-input game)))
    (decf (fill-pointer (wordle-game-input game))))
  game)

(defun try-submit (game)
  "Submits GAME's in-progress input as a guess if it's exactly the
answer's length, then clears it. No-ops otherwise — an incomplete guess
just stays on screen."
  (when (and (eq (wordle-game-status game) :playing)
             (= (fill-pointer (wordle-game-input game)) (length (wordle-game-answer game))))
    (submit-guess game (coerce (wordle-game-input game) 'string))
    (setf (fill-pointer (wordle-game-input game)) 0))
  game)
