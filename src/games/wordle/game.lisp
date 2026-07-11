(in-package :edm-engine/games/wordle)

(declaim (optimize (speed 3) (safety 3)))

(defconstant +pulse-max+ 12
  "Frames a just-typed tile's highlight pulse lasts, ~0.2s at 60fps.")

(define-condition invalid-word (error)
  ((guess :initarg :guess :reader invalid-word-guess))
  (:report (lambda (c s) (format s "~S is not a valid word" (invalid-word-guess c)))))

(defstruct (wordle-game (:constructor %make-wordle-game))
  (answer "" :type string)
  (history nil :type list)
  (max-rows 6 :type fixnum)
  (status :playing :type (member :playing :won :lost))
  (input (make-array 0 :element-type 'character :adjustable t :fill-pointer 0))
  (pulse 0 :type fixnum)
  (corpus nil :type list))

(declaim (ftype (function (string &key (:max-rows fixnum) (:corpus list)) wordle-game) make-wordle-game))
(defun make-wordle-game (answer &key (max-rows 6) (corpus *corpus*))
  (%make-wordle-game :answer (string-upcase answer) :max-rows max-rows :corpus corpus))

(declaim (ftype (function (string list) boolean) valid-word-p))
(defun valid-word-p (word corpus)
  (and (member (string-upcase word) corpus :test #'string=) t))

(declaim (ftype (function (wordle-game string) wordle-game) submit-guess))
(defun submit-guess (game guess)
  "Appends GUESS's feedback to GAME's history and updates GAME's status.
Signals an error if GAME already finished, GUESS isn't the right
length, or GUESS isn't in GAME's corpus (a real Wordle rule: guesses
must be actual words, not just any letter combination) — this is the
local BDD/e2e gate the CI pipeline doesn't need to re-check."
  (unless (eq (wordle-game-status game) :playing)
    (error "wordle-game already finished: ~A" (wordle-game-status game)))
  (unless (= (length guess) (length (wordle-game-answer game)))
    (error "guess ~S must be ~D letters" guess (length (wordle-game-answer game))))
  (unless (valid-word-p guess (wordle-game-corpus game))
    (error 'invalid-word :guess guess))
  (let* ((guess (string-upcase guess))
         (feedback (evaluate-guess guess (wordle-game-answer game))))
    (setf (wordle-game-history game)
          (append (wordle-game-history game) (list (cons guess feedback))))
    (cond ((string= guess (wordle-game-answer game))
           (setf (wordle-game-status game) :won))
          ((>= (length (wordle-game-history game)) (wordle-game-max-rows game))
           (setf (wordle-game-status game) :lost))))
  game)

(declaim (ftype (function (list fixnum) list) pad-row))
(defun pad-row (cells width)
  "Pads CELLS to exactly WIDTH with NIL — every row DRAW-GRID sees must
be full-width; a bare NIL row draws zero tiles, not blank placeholders."
  (append cells (make-list (- width (length cells)) :initial-element nil)))

(declaim (ftype (function (wordle-game) list) rows-for-render))
(defun rows-for-render (game)
  "Converts GAME's history, plus its in-progress input as one more row,
into DRAW-GRID's row format: MAX-ROWS rows, each exactly
(length answer) cells of (LETTER . STATE) or NIL."
  (let* ((width (length (wordle-game-answer game)))
         (played (mapcar (lambda (entry)
                            (loop for ch across (car entry)
                                  for st across (cdr entry)
                                  collect (cons ch st)))
                          (wordle-game-history game)))
         (current (when (< (length played) (wordle-game-max-rows game))
                    (pad-row (loop for ch across (wordle-game-input game)
                                   collect (cons ch :empty))
                             width)))
         (shown (append played (and current (list current)))))
    (append shown
            (loop repeat (- (wordle-game-max-rows game) (length shown))
                  collect (pad-row nil width)))))

(defun push-letter (game ch)
  "Appends CH (uppercased) to GAME's in-progress input, if GAME is
still playable, CH is a letter, and there's room for it. Resets the
just-typed pulse so the new tile briefly highlights."
  (when (and (eq (wordle-game-status game) :playing)
             (alpha-char-p ch)
             (< (fill-pointer (wordle-game-input game)) (length (wordle-game-answer game))))
    (vector-push-extend (char-upcase ch) (wordle-game-input game))
    (setf (wordle-game-pulse game) +pulse-max+))
  game)

(defun pop-letter (game)
  "Removes the last typed letter, if any."
  (when (plusp (fill-pointer (wordle-game-input game)))
    (decf (fill-pointer (wordle-game-input game))))
  game)

(defun try-submit (game)
  "Submits GAME's in-progress input as a guess if it's exactly the
answer's length. Returns :SUBMITTED (input cleared, history grew),
:REJECTED (not a corpus word — input stays so the player can fix it),
or :NOT-READY (incomplete input, untouched)."
  (cond
    ((not (and (eq (wordle-game-status game) :playing)
               (= (fill-pointer (wordle-game-input game)) (length (wordle-game-answer game)))))
     :not-ready)
    (t (handler-case
           (progn
             (submit-guess game (coerce (wordle-game-input game) 'string))
             (setf (fill-pointer (wordle-game-input game)) 0)
             :submitted)
         (invalid-word () :rejected)))))

(defun tick-pulse (game)
  "Decrements GAME's typed-letter highlight pulse by one frame, floored
at zero. Call once per GAME-UPDATE frame."
  (when (plusp (wordle-game-pulse game))
    (decf (wordle-game-pulse game)))
  game)

(defmethod edm-engine:game-outcome ((game wordle-game))
  (case (wordle-game-status game)
    (:won :win)
    (:lost :lose)
    (t nil)))

(defmethod edm-engine:game-score ((game wordle-game))
  "100 points per unused row when won (fewer guesses scores higher),
zero on a loss or mid-game."
  (if (eq (wordle-game-status game) :won)
      (* 100 (1+ (- (wordle-game-max-rows game) (length (wordle-game-history game)))))
      0))

(defmethod edm-engine:game-save-data ((game wordle-game))
  (list :answer (wordle-game-answer game)
        :history (wordle-game-history game)
        :max-rows (wordle-game-max-rows game)
        :status (wordle-game-status game)))

(defun wordle-restore-game (data)
  "Reconstructs a WORDLE-GAME from a GAME-SAVE-DATA plist — the paired
half of that method, registered as this table's GAME-ENTRY RESTORE-FN."
  (destructuring-bind (&key answer history max-rows status &allow-other-keys) data
    (let ((game (%make-wordle-game :answer answer :max-rows max-rows
                                    :status status :corpus *corpus*)))
      (setf (wordle-game-history game) history)
      game)))
