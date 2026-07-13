(in-package :edm-engine/games/queens/tests)
(in-suite :edm-engine-queens)

(test queens-theme-is-a-32-row-pattern
  "Four bars of eight eighth-note rows each."
  (is (= 32 (length (queens-theme-pattern)))))

(test queens-theme-every-row-has-three-channels
  "Melody, bass, and an on-the-offbeat comp stab (NIL on the downbeats)."
  (is (every (lambda (row) (= 3 (length row))) (queens-theme-pattern))))

(test queens-theme-bass-holds-one-root-per-bar
  "The bass changes once every 8 rows (one bar), not every row — a
sustained foundation under a faster-moving melody, not another line
just repeating the same 8-note figure."
  (let ((pattern (queens-theme-pattern)))
    (dotimes (bar 4)
      (let ((bass-notes-this-bar
              (remove-duplicates
               (loop for row-in-bar from 0 below 8
                     collect (car (second (nth (+ (* bar 8) row-in-bar) pattern)))))))
        (is (= 1 (length bass-notes-this-bar))
            "bar ~D's bass should hold one note, got ~A" bar bass-notes-this-bar)))))

(test queens-theme-bass-follows-a-I-V-vi-IV-progression
  "C3 G3 A3 F3 — a real, recognizable major-key progression, not
arbitrary notes."
  (let ((pattern (queens-theme-pattern)))
    (is (equal '(-21 -14 -12 -16)
               (loop for bar from 0 below 4
                     collect (car (second (nth (* bar 8) pattern))))))))

(test queens-theme-melody-changes-more-often-than-the-bass
  (let* ((pattern (queens-theme-pattern))
         (melody-notes (mapcar (lambda (row) (car (first row))) pattern)))
    (is (> (length (remove-duplicates melody-notes)) 4))))

(test queens-theme-comp-channel-only-plays-on-offbeats
  (let ((pattern (queens-theme-pattern)))
    (dotimes (bar 4)
      (dotimes (row-in-bar 8)
        (let ((comp (third (nth (+ (* bar 8) row-in-bar) pattern))))
          (if (oddp row-in-bar)
              (is (not (null comp)) "offbeat row ~D of bar ~D should have a comp stab" row-in-bar bar)
              (is (null comp) "downbeat row ~D of bar ~D should rest" row-in-bar bar)))))))

(test queens-theme-melody-resolves-back-to-its-starting-note
  "Ends on the same note it opens with — a real cadence, so the loop
seams cleanly back to bar 1."
  (let ((pattern (queens-theme-pattern)))
    (is (= (car (first (first pattern))) (car (first (car (last pattern))))))))
