(in-package :edm-engine/tests)
(in-suite :edm-engine)

(test main-menu-select-wraps-around
  (let ((state (make-arcade-state)))
    (is (= 0 (arcade-state-main-menu-index state)))
    (arcade-select-previous-main-menu state)
    (is (= (1- (length +main-menu-items+)) (arcade-state-main-menu-index state)))
    (arcade-select-next-main-menu state)
    (is (= 0 (arcade-state-main-menu-index state)))))

(test log-crash-writes-a-readable-entry-without-erroring
  "Regression coverage for #23 (the error boundary) — LOG-CRASH itself
should never become a second failure on top of the one it's logging,
and what it writes should actually be useful for debugging, not just
'something happened'."
  (let* ((temp-path (merge-pathnames (format nil "edm-engine-crash-test-~A.log" (random 1000000))
                                      (uiop:temporary-directory)))
         (edm-engine::*crash-log-path* temp-path))
    (unwind-protect
         (progn
           (edm-engine::log-crash (make-condition 'simple-error :format-control "spec test condition"))
           (is (probe-file temp-path))
           (is (search "spec test condition" (uiop:read-file-string temp-path))))
      (ignore-errors (delete-file temp-path)))))

(test drill-into-tables-enters-tables-mode
  (let ((state (make-arcade-state)))
    (setf (arcade-state-main-menu-index state) 0)
    (arcade-drill-into-main-menu-selection state)
    (is (eq :tables (arcade-state-mode state)))))

(test drill-into-engine-options-enters-options-mode
  (let ((state (make-arcade-state)))
    (setf (arcade-state-main-menu-index state) 1)
    (arcade-drill-into-main-menu-selection state)
    (is (eq :options (arcade-state-mode state)))))

(test drill-into-save-load-enters-save-load-mode
  (let ((state (make-arcade-state)))
    (setf (arcade-state-main-menu-index state) 2)
    (arcade-drill-into-main-menu-selection state)
    (is (eq :save-load (arcade-state-mode state)))))

(test back-to-main-menu-resets-mode
  (let ((state (make-arcade-state)))
    (setf (arcade-state-mode state) :options)
    (arcade-back-to-main-menu state)
    (is (eq :main-menu (arcade-state-mode state)))))

(test escaping-from-playing-returns-to-tables-not-main-menu
  ;; "return the table menu (game selection)", not the top-level menu
  (let ((edm-engine::*games* nil)
        (state (make-arcade-state)))
    (register-game "Stub" (lambda () :a-fake-game))
    (arcade-drill-into-main-menu-selection state) ; -> :tables
    (arcade-launch-selected state)
    (is (eq :playing (arcade-state-mode state)))
    (arcade-return-to-table-select state)
    (is (eq :tables (arcade-state-mode state)))
    (is (null (arcade-state-current-game state)))))

(test restart-current-relaunches-the-same-table-by-title
  (let ((edm-engine::*games* nil)
        (state (make-arcade-state))
        (calls 0))
    (register-game "Counted" (lambda () (incf calls) (list :instance calls)))
    (setf (arcade-state-mode state) :tables)
    (arcade-launch-selected state)
    (is (equal '(:instance 1) (arcade-state-current-game state)))
    (arcade-restart-current state)
    (is (equal '(:instance 2) (arcade-state-current-game state)))
    (is (eq :playing (arcade-state-mode state)))))

;;; Engine Options — volume control

(test volume-increase-clamps-at-one
  (let ((state (make-arcade-state)))
    (setf (arcade-state-volume state) 0.95)
    (arcade-increase-volume state)
    (is (= 1.0 (arcade-state-volume state)))))

(test volume-decrease-clamps-at-zero
  (let ((state (make-arcade-state)))
    (setf (arcade-state-volume state) 0.05)
    (arcade-decrease-volume state)
    (is (= 0.0 (arcade-state-volume state)))))

(test volume-adjusts-by-tenth-within-range
  (let ((state (make-arcade-state)))
    (setf (arcade-state-volume state) 0.5)
    (arcade-increase-volume state)
    (is (= 0.6 (arcade-state-volume state)))
    (arcade-decrease-volume state)
    (arcade-decrease-volume state)
    (is (= 0.4 (float (arcade-state-volume state) 1.0)))))

;;; Pause/outcome popup

(defclass spec-outcome-game () ((outcome :initarg :outcome :initform nil :accessor spec-game-outcome)
                                 (score :initarg :score :initform 0 :accessor spec-game-score)
                                 (save-data :initarg :save-data :initform nil :accessor spec-game-save-data)))
(defmethod game-outcome ((g spec-outcome-game)) (spec-game-outcome g))
(defmethod game-score ((g spec-outcome-game)) (spec-game-score g))
(defmethod game-save-data ((g spec-outcome-game)) (spec-game-save-data g))

;; #9: SAVE STATE must never appear for a game whose GAME-SAVE-DATA is
;; NIL (the default protocol method) — showing it anyway is the actual
;; bug this issue names: a fake-successful save that silently discards
;; state. SPEC-OUTCOME-GAME's own default (no :SAVE-DATA given) is NIL,
;; matching the real, unmodified games (Queens/Hearts/Yahtzee) that
;; still use the protocol's default method.
(test popup-items-include-resume-only-while-in-progress
  (is (equal '("Resume" "New Game" "Return to Tables")
             (arcade-popup-items (make-instance 'spec-outcome-game :outcome nil))))
  (is (equal '("New Game" "Return to Tables")
             (arcade-popup-items (make-instance 'spec-outcome-game :outcome :win)))))

(test popup-items-include-save-state-only-when-game-save-data-is-supported
  "GOAL: #9's actual fix — SAVE STATE only appears when the game
genuinely supports it, never as a fake-successful, silently-discarded
save."
  (is (equal '("Resume" "New Game" "Save State" "Return to Tables")
             (arcade-popup-items (make-instance 'spec-outcome-game :outcome nil :save-data '(:some "data")))))
  (is (equal '("New Game" "Save State" "Return to Tables")
             (arcade-popup-items (make-instance 'spec-outcome-game :outcome :win :save-data '(:some "data"))))))

(test popup-cycling-wraps-for-the-in-progress-variant
  (let ((edm-engine::*games* nil)
        (state (make-arcade-state)))
    (register-game "Stub" (lambda () (make-instance 'spec-outcome-game :save-data '(:some "data"))))
    (setf (arcade-state-mode state) :tables)
    (arcade-launch-selected state)
    (arcade-open-popup state)
    (is (= 0 (arcade-state-popup-index state)))
    (arcade-popup-previous state)
    (is (= 3 (arcade-state-popup-index state))) ; wraps to last of 4 items
    (arcade-popup-next state)
    (is (= 0 (arcade-state-popup-index state)))))

(test popup-confirm-resume-just-closes-popup
  (let ((edm-engine::*games* nil)
        (state (make-arcade-state)))
    (register-game "Stub" (lambda () (make-instance 'spec-outcome-game)))
    (setf (arcade-state-mode state) :tables)
    (arcade-launch-selected state)
    (arcade-open-popup state)
    (arcade-popup-confirm state)
    (is (not (arcade-state-popup-open state)))
    (is (eq :playing (arcade-state-mode state)))))

(test popup-confirm-new-game-dispatches-to-restart
  (let ((edm-engine::*games* nil)
        (state (make-arcade-state))
        (calls 0))
    (register-game "Stub" (lambda () (incf calls) (make-instance 'spec-outcome-game :outcome :win)))
    (setf (arcade-state-mode state) :tables)
    (arcade-launch-selected state)
    (is (= 1 calls))
    (arcade-open-popup state) ; outcome present -> items = (New Game, Save State, Return to Tables)
    (setf (arcade-state-popup-index state) 0)
    (arcade-popup-confirm state)
    (is (= 2 calls))
    (is (eq :playing (arcade-state-mode state)))))

(test popup-confirm-return-to-tables-dispatches-correctly
  (let ((edm-engine::*games* nil)
        (state (make-arcade-state)))
    (register-game "Stub" (lambda () (make-instance 'spec-outcome-game :outcome :win :save-data '(:some "data"))))
    (setf (arcade-state-mode state) :tables)
    (arcade-launch-selected state)
    (arcade-open-popup state)
    (setf (arcade-state-popup-index state) 2) ; "Return to Tables" in the finished-game variant
    (arcade-popup-confirm state)
    (is (eq :tables (arcade-state-mode state)))))

;;; Scoring

(test bank-score-adds-current-games-score-to-total
  (let ((edm-engine::*games* nil)
        (state (make-arcade-state)))
    (register-game "Stub" (lambda () (make-instance 'spec-outcome-game :outcome :win :score 250)))
    (setf (arcade-state-mode state) :tables)
    (arcade-launch-selected state)
    (arcade-bank-score state)
    (is (= 250 (arcade-state-total-score state)))))

(test bank-score-accumulates-across-multiple-games
  (let ((edm-engine::*games* nil)
        (state (make-arcade-state)))
    (register-game "Stub" (lambda () (make-instance 'spec-outcome-game :outcome :win :score 100)))
    (setf (arcade-state-mode state) :tables)
    (arcade-launch-selected state)
    (arcade-restart-current state) ; banks 100, launches a fresh 100-point instance
    (arcade-return-to-table-select state) ; banks another 100
    (is (= 200 (arcade-state-total-score state)))))

;;; Save via popup (10-slot system)

(defmacro with-temp-save-directory-for-arcade (&body body)
  `(let ((edm-engine::*save-directory* (merge-pathnames
                                         (format nil "edm-engine-arcade-test-saves-~A/" (random 1000000))
                                         (uiop:temporary-directory))))
     (unwind-protect (progn ,@body)
       (when (probe-file edm-engine::*save-directory*)
         (uiop:delete-directory-tree edm-engine::*save-directory* :validate t)))))

(test popup-save-state-pushes-a-save-game-event-and-returns-to-tables
  "Updated per #58 part 2's own architectural fix: ARCADE-POPUP-CONFIRM
(via ARCADE-SAVE-CURRENT) now pushes a :SAVE-GAME event rather than
writing to disk directly — the actual write is a separate consumer's
job (main.lisp's own render loop), covered by its own test once that
consumer exists, not this one."
  (with-temp-save-directory-for-arcade
    (let ((edm-engine::*games* nil)
          (state (make-arcade-state)))
      (register-game "Stub" (lambda () (make-instance 'spec-outcome-game :save-data '(:some "data"))))
      (setf (arcade-state-mode state) :tables)
      (arcade-launch-selected state)
      (setf (arcade-state-save-slot-index state) 3)
      (arcade-open-popup state)
      (setf (arcade-state-popup-index state) 2) ; "Save State" in the in-progress variant
      (multiple-value-bind (event received-p) (bus-try-pop *engine-bus* :save-game)
        (declare (ignore event received-p))) ; drain anything stale from a prior test
      (arcade-popup-confirm state)
      (is (eq :tables (arcade-state-mode state)))
      (multiple-value-bind (event received-p) (bus-try-pop *engine-bus* :save-game)
        (is (not (null received-p)))
        (is (= 3 (getf event :slot)))
        (is (string= "Stub" (getf event :table-title)))
        (is (equal '(:some "data") (getf event :data)))))))

(test save-slot-browsing-wraps-through-all-ten
  (let ((state (make-arcade-state)))
    (is (= 0 (arcade-state-save-slot-index state)))
    (arcade-select-previous-save-slot state)
    (is (= 9 (arcade-state-save-slot-index state)))
    (arcade-select-next-save-slot state)
    (is (= 0 (arcade-state-save-slot-index state)))))

(test load-selected-save-slot-returns-nil-when-that-slot-is-empty
  (with-temp-save-directory-for-arcade
    (let ((edm-engine::*games* nil)
          (state (make-arcade-state)))
      (register-game "Stub" (lambda () (make-instance 'spec-outcome-game))
                      :restore-fn (lambda (data) (declare (ignore data)) (make-instance 'spec-outcome-game)))
      (is (null (arcade-load-selected-save-slot state))))))

(test load-selected-save-slot-round-trips-title-and-score-and-resumes-play
  (with-temp-save-directory-for-arcade
    (let ((edm-engine::*games* nil)
          (state (make-arcade-state)))
      (register-game "Stub" (lambda () (make-instance 'spec-outcome-game))
                      :restore-fn (lambda (data) (declare (ignore data))
                                    (make-instance 'spec-outcome-game)))
      (save-game-to-slot 5 "Stub" (make-instance 'spec-outcome-game) 777)
      (setf (arcade-state-save-slot-index state) 5)
      (is (eq t (arcade-load-selected-save-slot state)))
      (is (eq :playing (arcade-state-mode state)))
      (is (string= "Stub" (arcade-state-current-table-title state)))
      (is (= 777 (arcade-state-total-score state))))))

(test load-selected-save-slot-returns-nil-when-table-has-no-restore-fn
  (with-temp-save-directory-for-arcade
    (let ((edm-engine::*games* nil)
          (state (make-arcade-state)))
      (register-game "Stub" (lambda () (make-instance 'spec-outcome-game))) ; no :restore-fn
      (save-game-to-slot 0 "Stub" (make-instance 'spec-outcome-game) 50)
      (is (null (arcade-load-selected-save-slot state))))))

;;; ARCADE-SAVE-CURRENT — #58 part 2, the actual architectural fix per
;;; direct question: the real "Save State" UI flow was calling
;;; SAVE-GAME-TO-SLOT and RAYLIB:TAKE-SCREENSHOT directly and
;;; synchronously in the same key-handler — the exact direct-call
;;; pattern #37's own bus-driven VFX trigger was built to replace,
;;; never applied to save-game itself. Game logic (this function)
;;; should push a semantic event, never write to disk directly; a
;;; consumer (main.lisp's own render loop, since the screenshot needs
;;; the GL context that thread owns) drains it. BDD-first, written
;;; before ARCADE-SAVE-CURRENT pushes anything.

(test arcade-save-current-pushes-a-save-game-event-with-precomputed-data
  "GOAL: GAME-SAVE-DATA is computed at push time, while the game object
is still current, not deferred to whatever drains the event later —
the event payload carries DATA itself (SPEC-SAVE-GAME's own known
value), not a game object the consumer would need to call back into."
  (with-temp-save-directory-for-arcade
    (let ((edm-engine::*games* nil)
          (state (make-arcade-state)))
      (register-game "Stub" (lambda () (make-instance 'spec-save-game :data 42)))
      (setf (arcade-state-mode state) :tables)
      (arcade-launch-selected state)
      (multiple-value-bind (event received-p) (bus-try-pop *engine-bus* :save-game)
        (declare (ignore event received-p))) ; drain anything stale from a prior test
      (arcade-save-current state)
      (multiple-value-bind (event received-p) (bus-try-pop *engine-bus* :save-game)
        (is (not (null received-p)))
        (is (= (arcade-state-save-slot-index state) (getf event :slot)))
        (is (string= "Stub" (getf event :table-title)))
        (is (= 42 (getf event :data)))))))

(test arcade-save-current-does-not-write-to-disk-directly-itself
  "GOAL: pushing the event is the whole job — no direct SAVE-GAME-TO-
SLOT/SAVE-SLOT-DATA call happens inside ARCADE-SAVE-CURRENT itself,
checked by confirming nothing lands on disk until a consumer actually
drains the bus, not assumed from the push succeeding alone."
  (with-temp-save-directory-for-arcade
    (let ((edm-engine::*games* nil)
          (state (make-arcade-state)))
      (register-game "Stub" (lambda () (make-instance 'spec-save-game :data 1)))
      (setf (arcade-state-mode state) :tables)
      (arcade-launch-selected state)
      (multiple-value-bind (event received-p) (bus-try-pop *engine-bus* :save-game)
        (declare (ignore event received-p)))
      (arcade-save-current state)
      (is (null (load-game-from-slot (arcade-state-save-slot-index state)))))))

(test arcade-save-current-still-returns-to-table-select-immediately
  "GOAL: the UI transition (back to table select) isn't gated on the
event actually being drained — a real UX property, checked directly
rather than assumed to still hold after this architectural change."
  (with-temp-save-directory-for-arcade
    (let ((edm-engine::*games* nil)
          (state (make-arcade-state)))
      (register-game "Stub" (lambda () (make-instance 'spec-save-game :data 1)))
      (setf (arcade-state-mode state) :tables)
      (arcade-launch-selected state)
      (arcade-save-current state)
      (is (eq :tables (arcade-state-mode state))))))
