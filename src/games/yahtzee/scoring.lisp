(in-package :edm-engine/games/yahtzee)

;;; Dice = a list of 5 integers, 1-6. The "roll a single d6" primitive
;;; is EDM-ENGINE:ROLL-DIE (src/dice.lisp, generic across die types);
;;; the "5 dice, hold-a-subset, reroll the rest" mechanic below is
;;; specifically Yahtzee's own, built on top of that primitive rather
;;; than reimplementing "roll a die" itself.

(defun roll-dice (seed)
  (loop for i from 0 below 5 collect (edm-engine:roll-die :d6 (+ seed (* i 97)))))

(defun reroll-dice (dice held seed)
  "Rerolls DICE at positions where HELD is NIL, leaves held positions
untouched."
  (loop for d in dice for h in held for i from 0
        collect (if h d (edm-engine:roll-die :d6 (+ seed (* i 97))))))

;;; Upper section — sum of matching-value dice

(defun score-n (dice n) (* n (count n dice)))
(defun score-ones (dice) (score-n dice 1))
(defun score-twos (dice) (score-n dice 2))
(defun score-threes (dice) (score-n dice 3))
(defun score-fours (dice) (score-n dice 4))
(defun score-fives (dice) (score-n dice 5))
(defun score-sixes (dice) (score-n dice 6))

;;; Lower section

(defun has-n-of-a-kind-p (dice n)
  (some (lambda (v) (>= (count v dice) n)) '(1 2 3 4 5 6)))

(defun score-three-of-a-kind (dice) (if (has-n-of-a-kind-p dice 3) (reduce #'+ dice) 0))
(defun score-four-of-a-kind (dice) (if (has-n-of-a-kind-p dice 4) (reduce #'+ dice) 0))

(defun dice-value-counts (dice)
  "The count of each present value, zeros excluded — e.g. (2 2 2 5 5)
-> (3 2), (3 3 3 3 3) -> (5)."
  (remove 0 (mapcar (lambda (v) (count v dice)) '(1 2 3 4 5 6))))

(defun score-full-house (dice)
  "Exactly a 3+2 split — five-of-a-kind is a Yahtzee, not a full house,
under the standard (non-joker) scorecard this implements."
  (let ((counts (dice-value-counts dice)))
    (if (and (= 2 (length counts)) (member 3 counts) (member 2 counts)) 25 0)))

(defun score-small-straight (dice)
  "Any four consecutive values present, anywhere in the five dice."
  (let ((unique (remove-duplicates dice)))
    (if (some (lambda (start) (every (lambda (v) (member v unique)) (loop for i from start below (+ start 4) collect i)))
              '(1 2 3))
        30 0)))

(defun score-large-straight (dice)
  (let ((sorted (sort (copy-list dice) #'<)))
    (if (or (equal sorted '(1 2 3 4 5)) (equal sorted '(2 3 4 5 6))) 40 0)))

(defun score-yahtzee (dice) (if (= 1 (length (remove-duplicates dice))) 50 0))

(defun score-chance (dice) (reduce #'+ dice))

(defparameter +categories+
  '(:ones :twos :threes :fours :fives :sixes
    :three-of-a-kind :four-of-a-kind :full-house
    :small-straight :large-straight :yahtzee :chance))

(defun upper-category-p (category)
  (member category '(:ones :twos :threes :fours :fives :sixes)))

(defun score-category (category dice)
  (ecase category
    (:ones (score-ones dice)) (:twos (score-twos dice)) (:threes (score-threes dice))
    (:fours (score-fours dice)) (:fives (score-fives dice)) (:sixes (score-sixes dice))
    (:three-of-a-kind (score-three-of-a-kind dice))
    (:four-of-a-kind (score-four-of-a-kind dice))
    (:full-house (score-full-house dice))
    (:small-straight (score-small-straight dice))
    (:large-straight (score-large-straight dice))
    (:yahtzee (score-yahtzee dice))
    (:chance (score-chance dice))))

;;; Totals

(defparameter +upper-bonus-threshold+ 63)
(defparameter +upper-bonus+ 35)

(defun upper-section-total (scores)
  "SCORES is a plist of category -> points, only some categories
necessarily present."
  (loop for cat in '(:ones :twos :threes :fours :fives :sixes)
        sum (or (getf scores cat) 0)))

(defun upper-bonus-p (scores)
  (>= (upper-section-total scores) +upper-bonus-threshold+))

(defun grand-total (scores)
  (+ (loop for (nil v) on scores by #'cddr sum v)
     (if (upper-bonus-p scores) +upper-bonus+ 0)))
