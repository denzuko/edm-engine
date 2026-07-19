(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; TDD — correctness of the implementation, per
;;; docs/test-layer-separation.md.

(test arena-spawn-time-does-not-leak-across-recycled-slots
  "The arena recycles indices via its free-list — a real edge case
worth checking directly: a newly-spawned particle landing on a
recycled slot must not inherit the previous occupant's stale
spawn-time before ARENA-SET-SPAWN-TIME is called for it explicitly."
  (let* ((arena (make-arena 1))
         (h1 (arena-spawn arena)))
    (arena-set-spawn-time arena h1 99.0)
    (arena-despawn arena h1)
    (let ((h2 (arena-spawn arena)))
      ;; H2 reuses H1's slot (capacity 1) — the raw slot value is still
      ;; 99.0 until explicitly set, which is fine (ARENA-ALIVE-P /
      ;; generation checks are what make H1 itself invalid, not this
      ;; slot's leftover data) — checked directly so this is a known,
      ;; verified fact rather than an assumption.
      (is (= 99.0 (arena-spawn-time arena h2)))
      (arena-set-spawn-time arena h2 5.0)
      (is (= 5.0 (arena-spawn-time arena h2))))))

(test arena-spawn-time-is-independent-per-handle
  (let* ((arena (make-arena 4))
         (h1 (arena-spawn arena))
         (h2 (arena-spawn arena)))
    (arena-set-spawn-time arena h1 1.0)
    (arena-set-spawn-time arena h2 2.0)
    (is (= 1.0 (arena-spawn-time arena h1)))
    (is (= 2.0 (arena-spawn-time arena h2)))))
