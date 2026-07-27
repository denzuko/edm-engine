(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; Systematic audit of src/games/hearts/*.lisp (per direct
;;; instruction: be systemic, not one hand-picked example) found
;;; several genuinely generic table/seating/selection primitives
;;; still living as if Hearts-specific. TARGET-PLAYER (seat rotation)
;;; belongs in EDM-ENGINE/CORE — it's not card-specific at all, any
;;; N-seat table game needs it (Boss Monster's own dungeon-building
;;; is multi-seat too). WRAP-CURSOR/TOGGLE-SELECTION are pure
;;; functions (return a new value, no mutation) — each game's own
;;; wrapper does the SETF, matching how EDM-ENGINE/CARDS' own
;;; generics already work.

(test target-player-left-right-across-none
  (is (= 1 (target-player 0 :left 4)))
  (is (= 3 (target-player 0 :right 4)))
  (is (= 2 (target-player 0 :across 4)))
  (is (= 0 (target-player 0 :none 4))))

(test target-player-generalizes-beyond-four-seats
  "Not hardcoded to Hearts' own 4-seat table — a 6-seat game's own
:LEFT/:RIGHT wrap differently."
  (is (= 1 (target-player 0 :left 6)))
  (is (= 5 (target-player 0 :right 6)))
  (is (= 3 (target-player 0 :across 6))))

(test wrap-cursor-moves-forward-and-backward
  (is (= 1 (wrap-cursor 0 1 13)))
  (is (= 12 (wrap-cursor 0 -1 13))))

(test wrap-cursor-wraps-past-the-ends
  (is (= 0 (wrap-cursor 12 1 13)))
  (is (= 12 (wrap-cursor 0 -1 13))))

(test wrap-cursor-with-zero-length-stays-put
  "A degenerate, empty hand shouldn't error — a genuine edge case, not
Hearts-specific behavior to preserve, but a real one any hand-cursor
consumer needs handled."
  (is (= 0 (wrap-cursor 0 1 0))))
