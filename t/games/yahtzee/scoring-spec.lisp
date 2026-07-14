(in-package :edm-engine/games/yahtzee/tests)
(in-suite :edm-engine-yahtzee)

;;; Dice rolling

(test roll-dice-gives-5-dice-values-1-to-6
  (let ((dice (roll-dice 1)))
    (is (= 5 (length dice)))
    (is (every (lambda (d) (<= 1 d 6)) dice))))

(test roll-dice-is-deterministic-per-seed
  (is (equal (roll-dice 7) (roll-dice 7))))

(test reroll-dice-keeps-held-positions-unchanged
  (let* ((dice '(1 2 3 4 5))
         (held '(t nil t nil nil))
         (result (reroll-dice dice held 99)))
    (is (= 5 (length result)))
    (is (= 1 (first result)))
    (is (= 3 (third result)))))

;;; Upper section scoring — sum of matching-value dice

(test score-ones-sums-only-the-ones
  (is (= 2 (score-ones '(1 1 3 4 5)))))

(test score-sixes-sums-only-the-sixes
  (is (= 12 (score-sixes '(6 6 1 2 3)))))

(test score-fours-with-none-present-is-zero
  (is (= 0 (score-fours '(1 2 3 5 6)))))

;;; Lower section

(test three-of-a-kind-sums-all-dice-when-three-match
  (is (= 19 (score-three-of-a-kind '(3 3 3 4 6)))))

(test three-of-a-kind-with-no-triple-is-zero
  (is (= 0 (score-three-of-a-kind '(1 2 3 4 5)))))

(test four-of-a-kind-sums-all-dice-when-four-match
  (is (= 20 (score-four-of-a-kind '(2 2 2 2 12)))))

(test four-of-a-kind-three-of-a-kind-is-not-enough
  (is (= 0 (score-four-of-a-kind '(2 2 2 4 5)))))

(test full-house-is-25-for-three-plus-two
  (is (= 25 (score-full-house '(2 2 2 5 5)))))

(test full-house-five-of-a-kind-does-not-count-in-standard-rules
  "Five matching dice is a Yahtzee, not a full house by the standard
scorecard — this game doesn't implement the optional joker rule."
  (is (= 0 (score-full-house '(3 3 3 3 3)))))

(test full-house-four-plus-one-is-not-a-full-house
  (is (= 0 (score-full-house '(2 2 2 2 5)))))

(test small-straight-is-30-for-four-consecutive
  (is (= 30 (score-small-straight '(1 2 3 4 6)))))

(test small-straight-recognizes-any-four-run-within-five-dice
  (is (= 30 (score-small-straight '(2 3 4 5 5)))))

(test small-straight-with-no-run-of-four-is-zero
  (is (= 0 (score-small-straight '(1 1 3 5 6)))))

(test large-straight-is-40-for-five-consecutive
  (is (= 40 (score-large-straight '(2 3 4 5 6)))))

(test large-straight-out-of-order-still-counts
  (is (= 40 (score-large-straight '(6 4 2 5 3)))))

(test large-straight-with-a-gap-is-zero
  (is (= 0 (score-large-straight '(1 2 3 4 4)))))

(test yahtzee-is-50-for-five-matching
  (is (= 50 (score-yahtzee '(4 4 4 4 4)))))

(test yahtzee-four-matching-is-zero
  (is (= 0 (score-yahtzee '(4 4 4 4 5)))))

(test chance-is-the-sum-of-all-dice-regardless-of-pattern
  (is (= 21 (score-chance '(1 2 3 6 9)))))

;;; Category dispatch

(test score-category-dispatches-to-the-right-scorer
  (is (= 25 (score-category :full-house '(6 6 6 2 2))))
  (is (= 50 (score-category :yahtzee '(1 1 1 1 1)))))

;;; Upper bonus

(test upper-section-total-sums-only-the-six-upper-categories
  (let ((scores (list :ones 3 :twos 6 :threes 0 :fours 0 :fives 0 :sixes 0
                       :three-of-a-kind 20 :chance 15)))
    (is (= 9 (upper-section-total scores)))))

(test upper-bonus-p-true-at-exactly-63
  (is (upper-bonus-p (list :ones 3 :twos 6 :threes 9 :fours 12 :fives 15 :sixes 18))))

(test upper-bonus-p-false-just-under-63
  (is (not (upper-bonus-p (list :ones 3 :twos 6 :threes 9 :fours 12 :fives 15 :sixes 17)))))

(test grand-total-includes-upper-bonus-when-earned
  (let ((scores (list :ones 5 :twos 10 :threes 15 :fours 12 :fives 15 :sixes 18 :chance 20)))
    ;; upper = 5+10+15+12+15+18 = 75 >= 63, bonus 35; +chance 20 = 130
    (is (= 130 (grand-total scores)))))

(test grand-total-excludes-bonus-when-not-earned
  (let ((scores (list :ones 1 :twos 2 :threes 3 :chance 20)))
    (is (= 26 (grand-total scores)))))
