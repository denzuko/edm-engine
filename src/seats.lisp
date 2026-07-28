(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

;;; Generic to any multi-seat table game — not card-specific at all
;;; (Boss Monster's own dungeon-building is multi-seat too). Moved
;;; from src/games/hearts/game.lisp, where TARGET-PLAYER lived as if
;;; Hearts-specific despite being a plain N-seat rotation, and MOVE-
;;; HAND-CURSOR's own cursor-wrapping logic lived tangled with a
;;; direct SETF, when the actual wrap arithmetic has nothing to do
;;; with Hearts or even cards — any selectable-item cursor needs it.

(defun target-player (player direction seat-count)
  "The seat SEAT-COUNT-modulo DIRECTION away from PLAYER — :LEFT/
:RIGHT/:ACROSS/:NONE around an N-seat table. Generalized from Hearts'
own hardcoded 4 seats; a future table game may have a different
count. :ACROSS assumes an even SEAT-COUNT (the natural 'opposite
seat' only exists then) — Hearts' own 4-seat table satisfies this;
callers with an odd seat count shouldn't use :ACROSS."
  (ecase direction
    (:left (mod (1+ player) seat-count))
    (:right (mod (1- player) seat-count))
    (:across (mod (+ player (floor seat-count 2)) seat-count))
    (:none player)))

(defun wrap-cursor (cursor delta length)
  "CURSOR shifted by DELTA, wrapped within 0..LENGTH-1. LENGTH zero
(a degenerate, empty hand) returns CURSOR unchanged rather than
erroring on a MOD-by-zero — a real edge case any hand-cursor consumer
needs handled, not Hearts-specific behavior being preserved."
  (if (plusp length) (mod (+ cursor delta) length) cursor))

(defun clamp-cursor (value size)
  "VALUE clamped to 0..SIZE-1 — stops at the edge rather than cycling
to the opposite side, the genuinely different sibling to WRAP-CURSOR.
Generalized from Queens' own CLAMP-TO-BOARD: a board/grid cursor
should stop at the edge (running off a board makes no sense), while a
hand cursor wraps (there's no 'edge' to a circular row of cards)."
  (max 0 (min (1- size) value)))
