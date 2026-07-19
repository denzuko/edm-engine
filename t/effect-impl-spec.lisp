(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; TDD — correctness of the implementation, per
;;; docs/test-layer-separation.md. Precise, detailed, expected to need
;;; real debugging on first pass (and did — both PULSEVAL tests below
;;; had wrong expected values on first write, traced and fixed here,
;;; not in the BDD file next door, which is the actual point of the
;;; split this file exists to prove).

(test pulse-val-matches-queens-existing-shader-formula-at-known-points
  "PULSEVAL must reproduce Queens' own, already-proven cell shader
formula (0.5 + 0.5*sin(time*6.0)) exactly at known points, not just
resemble it — this is a generalization of working code, not a new
design invented from scratch. :BASE 0/:AMPLITUDE 1 isolates the raw
0-1 oscillation, matching Queens' own bare PULSE variable before its
shader applies the separate V = 0.7 + 0.3*pulse scaling."
  (is (= 0.5 (pulseVal 0.0d0 :period (/ (* 2 pi) 6.0d0) :base 0.0 :amplitude 1.0)))
  (is (< (abs (- 1.0 (pulseVal (/ pi 12.0d0) :period (/ (* 2 pi) 6.0d0) :base 0.0 :amplitude 1.0))) 0.0001)))

(test pulse-val-base-and-amplitude-scale-the-oscillation-exactly
  "Queens applies the raw 0-1 pulse as V = 0.7 + 0.3*pulse — PULSEVAL
should do that scaling itself via :BASE/:AMPLITUDE, not leave every
caller to re-derive it. At ELAPSED=0 the raw pulse is 0.5 (not 0 —
sin(0)=0, so 0.5+0.5*0=0.5), so the scaled result is 0.7 + 0.3*0.5 =
0.85, matching Queens' own formula exactly, not a simplified
approximation of it. Wrong on first write (asserted 0.7, the actual
BASE value rather than the correctly-scaled result) — caught and
fixed here, in the TDD layer, not by editing the BDD file's broader
assertion next door."
  (is (= 0.85 (pulseVal 0.0d0 :period 1.0d0 :base 0.7 :amplitude 0.3))))

(test ese-tracks-elapsed-time-since-a-state-became-active-not-wall-clock
  "The real point of generalizing away from Queens' global TIME
uniform: a pulse should start fresh when a cell is newly selected, not
be phase-locked to however long the program has been running. Checked
directly — entering at t=10.0 and querying at t=10.5 must report 0.5s
elapsed exactly, not 10.5."
  (clearEse)
  (is (= 0.0d0 (ese :test-key t 10.0d0)))
  (is (= 0.5d0 (ese :test-key t 10.5d0))))

(test ese-resets-on-exit-so-re-entry-starts-a-fresh-pulse
  "Deactivating and reactivating must restart the elapsed clock at
exactly 0, not resume — a cursor leaving and re-entering a cell is a
new pulse, not a continuation of the old one."
  (clearEse)
  (ese :test-key t 10.0d0)
  (is (null (ese :test-key nil 10.2d0)))
  (is (= 0.0d0 (ese :test-key t 20.0d0))))

(test ese-tracks-independent-keys-separately-with-exact-values
  "Two different keys must not share entry times — checked with exact
elapsed values for each, not just 'they differ'."
  (clearEse)
  (ese :key-a t 5.0d0)
  (ese :key-b t 8.0d0)
  (is (= 1.0d0 (ese :key-a t 6.0d0)))
  (is (= 1.0d0 (ese :key-b t 9.0d0))))
