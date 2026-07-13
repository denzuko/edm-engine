(in-package :edm-engine)

;;; AI pacing timer — "wait N seconds between AI actions so a human can
;;; see what's happening," generalized from what was Hearts-specific
;;; bookkeeping (*AI-NEXT-ACTION-TIME*). The SECOND real use case
;;; (Yahtzee, per the reasoning that prompted this extraction) is what
;;; justifies pulling it out now rather than letting Yahtzee reinvent
;;; it — same discipline as the cards/shader/tween extractions.

(defstruct ai-timer
  (next-action-time 0.0d0 :type double-float))

(declaim (ftype (function (ai-timer double-float) boolean) ai-ready-p))
(defun ai-ready-p (timer now)
  (>= now (ai-timer-next-action-time timer)))

(declaim (ftype (function (ai-timer double-float double-float) ai-timer) ai-timer-reset))
(defun ai-timer-reset (timer now delay)
  (setf (ai-timer-next-action-time timer) (+ now delay))
  timer)

;;; Difficulty tiers — a shared concept any AI-opponent game hooks its
;;; own decision logic into. The tier list and the selection screen are
;;; shared; what NOVICE/STANDARD/EXPERT actually mean for a given
;;; game's AI (which heuristic, whether it's worth a SCREAMER search)
;;; is that game's own business, not this library's.

(defparameter +ai-difficulty-tiers+ '(:novice :standard :expert))

(defparameter +ai-difficulty-labels+
  '((:novice . "Novice") (:standard . "Standard") (:expert . "Expert")))

(defparameter +ai-difficulty-glyphs+
  '((:novice . "♟") (:standard . "♞") (:expert . "♛"))
  "Pawn/knight/queen — chess pieces already carry a natural low-to-high
skill hierarchy, so this reuses that instead of inventing new iconography
or needing portrait assets.")

(defparameter +ai-difficulty-descriptions+
  '((:novice . "Plays safe, doesn't plan ahead")
    (:standard . "Tracks what's been played, avoids risk")
    (:expert . "Searches ahead for the strongest line")))

(declaim (ftype (function ((member :novice :standard :expert)) string) ai-difficulty-label))
(defun ai-difficulty-label (tier)
  (cdr (assoc tier +ai-difficulty-labels+)))

(defvar *ai-difficulty* :novice
  "Bound around an AI-capable GAME-ENTRY's constructor call to whatever
tier the player picked on the difficulty-selection screen — read it in
your own MAKE-<GAME> constructor if your AI cares about difficulty;
ignored entirely by games that don't register as AI-capable.")
