(in-package :edm-engine/games/wordle/tests)
(in-suite :edm-engine-wordle)

(test evaluate-guess-all-green-when-guess-equals-answer
  (is (equalp #(:green :green :green :green :green)
              (evaluate-guess "SPEED" "SPEED"))))

(test evaluate-guess-all-gray-when-no-shared-letters
  (is (equalp #(:gray :gray :gray :gray :gray)
              (evaluate-guess "CLUMP" "TIRED"))))

(test evaluate-guess-caps-yellow-count-by-remaining-letters
  "Answer SPEED has one non-green E available after the green pass finds
none; guess ERASE has two E's. Left-to-right consumption yields yellow on
the first E, gray on the second — this is the classic duplicate-letter
Wordle edge case."
  (is (equalp #(:yellow :gray :gray :yellow :yellow)
              (evaluate-guess "ERASE" "SPEED"))))

(test evaluate-guess-green-consumes-before-yellow-pass
  "Answer MONEY has exactly one O, consumed by the green match at pos1.
Guess NOOSE's second O (pos2) has no O left in MONEY's remaining pool, so
it grays out rather than double-counting against a letter already spent
by the green pass."
  (is (equalp #(:yellow :green :gray :gray :yellow)
              (evaluate-guess "NOOSE" "MONEY"))))

(test filter-candidates-narrows-to-consistent-words
  (let* ((corpus '("SPEED" "SPARE" "STEED" "TRAIN"))
         (feedback (evaluate-guess "SPEED" "STEED"))
         (survivors (filter-candidates corpus (list (cons "SPEED" feedback)))))
    (is (member "STEED" survivors :test #'string=))
    (is (not (member "TRAIN" survivors :test #'string=)))))
