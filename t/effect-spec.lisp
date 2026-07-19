(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; BDD-first, per direct correction to this session's own practice
;;; (#20): written before PULSEVAL/ESE exist, expected to fail until
;;; they're implemented — the goal gate, not a regression test added
;;; after the fact. #37's DEFEFFECT-STATE design names this exact
;;; case (Queens' cursor pulse, generalized) as its own worked example;
;;; this is that generalization's pure core, proven before the macro
;;; syntax around it is attempted.

(test pulse-val-matches-queens-existing-shader-formula-at-known-points
  "PULSEVAL must reproduce Queens' own, already-proven cell shader
formula (0.5 + 0.5*sin(time*6.0)) exactly at known points, not just
resemble it — this is a generalization of working code, not a new
design invented from scratch. :BASE 0/:AMPLITUDE 1 isolates the raw
0-1 oscillation, matching Queens' own bare PULSE variable before its
shader applies the separate V = 0.7 + 0.3*pulse scaling."
  (is (= 0.5 (pulseVal 0.0d0 :period (/ (* 2 pi) 6.0d0) :base 0.0 :amplitude 1.0)))
  (is (< (abs (- 1.0 (pulseVal (/ pi 12.0d0) :period (/ (* 2 pi) 6.0d0) :base 0.0 :amplitude 1.0))) 0.0001)))

(test pulse-val-base-and-amplitude-scale-the-oscillation
  "Queens applies the raw 0-1 pulse as V = 0.7 + 0.3*pulse — PULSEVAL
should do that scaling itself via :BASE/:AMPLITUDE, not leave every
caller to re-derive it, the actual point of generalizing rather than
just extracting the bare oscillation. At ELAPSED=0 the raw pulse is
0.5 (not 0 — sin(0)=0, so 0.5+0.5*0=0.5), so the scaled result is
0.7 + 0.3*0.5 = 0.85, matching Queens' own formula exactly, not a
simplified approximation of it."
  (is (= 0.85 (pulseVal 0.0d0 :period 1.0d0 :base 0.7 :amplitude 0.3))))

(test ese-tracks-elapsed-time-since-a-state-became-active-not-wall-clock
  "The real point of generalizing away from Queens' global TIME
uniform: a pulse should start fresh when a cell is newly selected, not
be phase-locked to however long the program has been running. Checked
directly — entering at t=10.0 and querying at t=10.5 must report 0.5s
elapsed, not 10.5."
  (clearEse)
  (is (= 0.0d0 (ese :test-key t 10.0d0)))
  (is (= 0.5d0 (ese :test-key t 10.5d0))))

(test ese-resets-on-exit-so-re-entry-starts-a-fresh-pulse
  "Deactivating and reactivating must restart the elapsed clock at 0,
not resume — a cursor leaving and re-entering a cell is a new pulse,
not a continuation of the old one."
  (clearEse)
  (ese :test-key t 10.0d0)
  (is (null (ese :test-key nil 10.2d0)))
  (is (= 0.0d0 (ese :test-key t 20.0d0))))

(test ese-tracks-independent-keys-separately
  "Two different keys must not share entry times — a real bug this
shape would have if the tracker used one global timestamp instead of
a table keyed per caller."
  (clearEse)
  (ese :key-a t 5.0d0)
  (ese :key-b t 8.0d0)
  (is (= 1.0d0 (ese :key-a t 6.0d0)))
  (is (= 1.0d0 (ese :key-b t 9.0d0))))
