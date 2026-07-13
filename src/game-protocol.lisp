(in-package :edm-engine)


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

(defgeneric game-score (game)
  (:documentation "Points GAME has earned this round. Banked into the
arcade's running total when the player leaves the table (new game, save,
or return to tables) — not per-frame, so a game sitting on its outcome
screen doesn't double-count.")
  (:method (game) (declare (ignore game)) 0))

(defgeneric game-save-data (game)
  (:documentation "A plain S-expression representing GAME's persistent
state — PRIN1-able and READable back, no CLOS objects or closures. NIL
means this table doesn't support save/load. Restoring it back into a
live instance is the paired GAME-ENTRY's RESTORE-FN, since that requires
knowing the concrete type to reconstruct — a generic can't do that from
a plist alone.")
  (:method (game) (declare (ignore game)) nil))

(defstruct game-entry
  "One arcade menu entry. CONSTRUCTOR takes no args and returns a fresh
game instance — called on selection, not at registration, so games with
randomized setup (a fresh Wordle answer, a shuffled deck) get a new one
each time they're launched, not once at load time. RESTORE-FN takes the
plist a prior GAME-SAVE-DATA produced and returns a live instance; NIL
means this table doesn't support save/load."
  (title "" :type string)
  (constructor (lambda () (error "no constructor")) :type function)
  (restore-fn nil :type (or null function)))

(defvar *games* nil "Registered GAME-ENTRY list, menu order = registration order.")

(defun register-game (title constructor &key restore-fn)
  "Adds TITLE to the arcade menu, backed by CONSTRUCTOR. Re-registering
an existing TITLE replaces its entry in place rather than moving it."
  (let ((existing (find title *games* :key #'game-entry-title :test #'string=)))
    (if existing
        (setf (game-entry-constructor existing) constructor
              (game-entry-restore-fn existing) restore-fn)
        (setf *games* (append *games* (list (make-game-entry :title title :constructor constructor
                                                               :restore-fn restore-fn)))))))
