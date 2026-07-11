(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

(defgeneric game-title (game)
  (:documentation "Display name shown in the arcade menu."))

(defgeneric game-update (game)
  (:documentation "Called once per frame while GAME is active. Reads
input and mutates GAME. Pure state transitions belong on the game's own
struct/functions, tested by FiveAM; only the raylib input reads here are
untested I/O, same boundary as RENDER.LISP."))

(defgeneric game-render (game window-width window-height)
  (:documentation "Called once per frame after GAME-UPDATE. Draws GAME's
current state. No logic — GAME-UPDATE already decided what state to draw."))

(defgeneric game-outcome (game)
  (:documentation "NIL while GAME is still in progress, or one of
:WIN/:LOSE/:TIE once it's over. The arcade shell uses this — not any
per-game code — to trigger the outcome overlay and restart prompt, so
every table gets that feedback for free by implementing this method.")
  (:method (game) (declare (ignore game)) nil))

(defstruct game-entry
  "One arcade menu entry. CONSTRUCTOR takes no args and returns a fresh
game instance — called on selection, not at registration, so games with
randomized setup (a fresh Wordle answer, a shuffled deck) get a new one
each time they're launched, not once at load time."
  (title "" :type string)
  (constructor (lambda () (error "no constructor")) :type function))

(defvar *games* nil "Registered GAME-ENTRY list, menu order = registration order.")

(defun register-game (title constructor)
  "Adds TITLE to the arcade menu, backed by CONSTRUCTOR. Re-registering
an existing TITLE replaces its entry in place rather than moving it."
  (let ((existing (find title *games* :key #'game-entry-title :test #'string=)))
    (if existing
        (setf (game-entry-constructor existing) constructor)
        (setf *games* (append *games* (list (make-game-entry :title title :constructor constructor)))))))
