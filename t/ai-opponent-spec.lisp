(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; AI pacing timer — generic "wait N seconds between AI actions" so a
;;; human can see what's happening, extracted from what was Hearts-
;;; specific *AI-NEXT-ACTION-TIME* bookkeeping.

(test ai-timer-not-ready-before-its-time
  (let ((timer (make-ai-timer)))
    (ai-timer-reset timer 10.0d0 0.8d0)
    (is (not (ai-ready-p timer 10.5d0)))))

(test ai-timer-ready-once-delay-elapses
  (let ((timer (make-ai-timer)))
    (ai-timer-reset timer 10.0d0 0.8d0)
    (is (ai-ready-p timer 10.8d0))
    (is (ai-ready-p timer 11.0d0))))

(test ai-timer-starts-ready
  (is (ai-ready-p (make-ai-timer) 0.0d0)))

;;; RUN-AI-TURN-WHEN-READY — the generic outer shape behind both
;;; Hearts' and Yahtzee's own MAYBE-RUN-AI-TURN, designed against both
;;; real consumers at once (per direct instruction: not generalized
;;; from Hearts alone, which risked the wrong abstraction — Yahtzee's
;;; own, already-existing MAYBE-RUN-AI-TURN is a second, real
;;; consumer, not a hypothetical one). The genuinely shared part: a
;;; guard (not my turn, AI-timer ready) wrapping an arbitrary ACT-FN,
;;; then resetting the timer — the decision+action logic itself
;;; (Hearts plays a card; Yahtzee either rolls dice or commits a
;;; score) stays each game's own, entirely different callback, never
;;; forced into one shared shape.

(test run-ai-turn-when-ready-does-not-act-when-it-is-the-players-own-turn
  (let ((timer (make-ai-timer)) (acted nil))
    (run-ai-turn-when-ready timer 0.0d0 0 0.5d0 (lambda () (setf acted t)))
    (is (not acted))))

(test run-ai-turn-when-ready-does-not-act-before-the-timer-is-ready
  (let ((timer (make-ai-timer)) (acted nil))
    (ai-timer-reset timer 0.0d0 10.0d0)
    (run-ai-turn-when-ready timer 1.0d0 2 0.5d0 (lambda () (setf acted t)))
    (is (not acted))))

(test run-ai-turn-when-ready-acts-and-resets-the-timer-when-both-conditions-hold
  (let ((timer (make-ai-timer)) (acted nil))
    (run-ai-turn-when-ready timer 5.0d0 2 0.8d0 (lambda () (setf acted t)))
    (is-true acted)
    (is (not (ai-ready-p timer 5.5d0)))
    (is (ai-ready-p timer 5.9d0))))

;;; Difficulty tiers — shared concept any AI-opponent game hooks its
;;; own decision logic into; the tier list and selection UI are
;;; shared, the algorithm per tier is each game's own.

(test ai-difficulty-tiers-are-novice-standard-expert
  (is (equal '(:novice :standard :expert) +ai-difficulty-tiers+)))

(test ai-difficulty-label-for-each-tier
  (is (string= "Novice" (ai-difficulty-label :novice)))
  (is (string= "Standard" (ai-difficulty-label :standard)))
  (is (string= "Expert" (ai-difficulty-label :expert))))

;;; GAME-ENTRY/REGISTER-GAME: AI-capable games route through a
;;; difficulty-selection screen before launch; others don't.

(test register-game-defaults-to-not-ai-capable
  (let ((edm-engine::*games* nil))
    (register-game "Plain" (lambda () :fake))
    (is (not (game-entry-ai-capable-p (first *games*))))))

(test register-game-can-be-marked-ai-capable
  (let ((edm-engine::*games* nil))
    (register-game "WithAI" (lambda () :fake) :ai-capable-p t)
    (is (game-entry-ai-capable-p (first *games*)))))

;;; Arcade shell: launching an AI-capable table routes through
;;; :DIFFICULTY first; a plain table goes straight to :PLAYING, same
;;; as before this feature existed.

(test launching-a-plain-table-goes-straight-to-playing
  (let ((edm-engine::*games* nil)
        (state (make-arcade-state)))
    (register-game "Plain" (lambda () :fake))
    (setf (arcade-state-mode state) :tables)
    (arcade-launch-selected state)
    (is (eq :playing (arcade-state-mode state)))))

(test launching-an-ai-capable-table-goes-to-difficulty-select-first
  (let ((edm-engine::*games* nil)
        (state (make-arcade-state)))
    (register-game "WithAI" (lambda () :fake) :ai-capable-p t)
    (setf (arcade-state-mode state) :tables)
    (arcade-launch-selected state)
    (is (eq :difficulty (arcade-state-mode state)))))

(test confirming-a-difficulty-selection-launches-the-table
  (let ((edm-engine::*games* nil)
        (state (make-arcade-state)))
    (register-game "WithAI" (lambda () :fake) :ai-capable-p t)
    (setf (arcade-state-mode state) :tables)
    (arcade-launch-selected state)
    (arcade-confirm-difficulty state)
    (is (eq :playing (arcade-state-mode state)))))

(test difficulty-selection-cursor-cycles-through-tiers
  (let ((state (make-arcade-state)))
    (is (= 0 (arcade-state-difficulty-index state)))
    (arcade-select-next-difficulty state)
    (is (= 1 (arcade-state-difficulty-index state)))
    (arcade-select-previous-difficulty state)
    (is (= 0 (arcade-state-difficulty-index state)))))

(test confirmed-difficulty-is-bound-for-the-constructor-to-read
  (let ((edm-engine::*games* nil)
        (state (make-arcade-state))
        (seen nil))
    (register-game "WithAI" (lambda () (setf seen *ai-difficulty*) :fake) :ai-capable-p t)
    (setf (arcade-state-mode state) :tables)
    (arcade-launch-selected state)
    (arcade-select-next-difficulty state) ; -> :standard
    (arcade-confirm-difficulty state)
    (is (eq :standard seen))))
