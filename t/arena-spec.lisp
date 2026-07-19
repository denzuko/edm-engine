(in-package :edm-engine/tests)
(in-suite :edm-engine)

(test arena-spawn-yields-alive-handle
  (let* ((arena (make-arena 8))
         (h (arena-spawn arena)))
    (is (arena-alive-p arena h))))

(test arena-despawn-invalidates-handle
  (let* ((arena (make-arena 8))
         (h (arena-spawn arena)))
    (arena-despawn arena h)
    (is (not (arena-alive-p arena h)))))

(test arena-recycled-slot-bumps-generation
  (let* ((arena (make-arena 1))
         (h1 (arena-spawn arena)))
    (arena-despawn arena h1)
    (let ((h2 (arena-spawn arena)))
      (is (= (handle-index h1) (handle-index h2)))
      (is (not (= (handle-generation h1) (handle-generation h2))))
      (is (not (arena-alive-p arena h1)))
      (is (arena-alive-p arena h2)))))

(test arena-full-signals-error
  (let ((arena (make-arena 1)))
    (arena-spawn arena)
    (signals error (arena-spawn arena))))

(test arena-position-round-trips
  (let* ((arena (make-arena 4))
         (h (arena-spawn arena)))
    (arena-set-position arena h 3.0 4.0)
    (multiple-value-bind (x y) (arena-position arena h)
      (is (= x 3.0))
      (is (= y 4.0)))))

(test arena-live-handles-excludes-despawned
  (let* ((arena (make-arena 4))
         (h1 (arena-spawn arena))
         (h2 (arena-spawn arena)))
    (arena-despawn arena h1)
    (let ((live (arena-live-handles arena)))
      (is (= 1 (length live)))
      (is (handle= h2 (first live))))))

;; BDD, per docs/test-layer-separation.md — written before
;; ARENA-SPAWN-TIME/ARENA-SET-SPAWN-TIME exist, the new component
;; #46's confetti/particle work (the arena's first real adoption per
;; #33) needs to track a particle's age for despawning. Broad —
;; precise arithmetic lives in arena-impl-spec.lisp.
(test a-spawned-particle-can-record-and-recall-a-spawn-time
  "GOAL: particles need to know when they were spawned, to know when
they've expired — a new component, same pattern as POSITION/VELOCITY."
  (let* ((arena (make-arena 4))
         (h (arena-spawn arena)))
    (arena-set-spawn-time arena h 5.0)
    (is (= 5.0 (arena-spawn-time arena h)))))
