(in-package :edm-engine/games/hearts/tests)
(in-suite :edm-engine-hearts)

(test make-deck-is-52-unique-cards
  (let ((deck (make-deck)))
    (is (= 52 (length deck)))
    (is (= 52 (length (remove-duplicates deck :test #'equal))))))

(test shuffled-deck-same-52-cards-different-order
  (let ((a (shuffled-deck 1)) (b (make-deck)))
    (is (= 52 (length a)))
    (is (null (set-difference a b :test #'equal)))))

(test shuffled-deck-is-deterministic-per-seed
  (is (equal (shuffled-deck 7) (shuffled-deck 7))))

(test shuffled-deck-differs-for-different-seeds
  (is (not (equal (shuffled-deck 1) (shuffled-deck 2)))))

(test deal-hands-makes-four-hands-of-thirteen-no-overlap
  (let ((hands (deal-hands (shuffled-deck 3))))
    (is (= 4 (length hands)))
    (is (every (lambda (h) (= 13 (length h))) hands))
    (is (= 52 (length (remove-duplicates (apply #'append hands) :test #'equal))))))

(test card-points-hearts-are-one-point
  (is (= 1 (card-points (cons 5 :hearts)))))

(test card-points-queen-of-spades-is-thirteen
  (is (= 13 (card-points (cons 12 :spades)))))

(test card-points-everything-else-is-zero
  (is (= 0 (card-points (cons 14 :clubs))))
  (is (= 0 (card-points (cons 12 :diamonds))))
  (is (= 0 (card-points (cons 13 :spades)))))

(test pass-direction-cycles-left-right-across-none
  (is (eq :left (pass-direction-for-round 1)))
  (is (eq :right (pass-direction-for-round 2)))
  (is (eq :across (pass-direction-for-round 3)))
  (is (eq :none (pass-direction-for-round 4)))
  (is (eq :left (pass-direction-for-round 5))))

;;; Legal plays

(test legal-plays-must-follow-suit-if-possible
  (let ((hand (list (cons 5 :hearts) (cons 9 :clubs) (cons 2 :spades))))
    (is (equal (list (cons 9 :clubs))
               (legal-plays hand :led-suit :clubs :hearts-broken t :leading-p nil)))))

(test legal-plays-any-card-if-void-in-led-suit
  (let ((hand (list (cons 5 :hearts) (cons 9 :clubs))))
    (is (equal hand (legal-plays hand :led-suit :diamonds :hearts-broken t :leading-p nil)))))

(test legal-plays-leading-cannot-play-hearts-until-broken
  (let ((hand (list (cons 5 :hearts) (cons 9 :clubs))))
    (is (equal (list (cons 9 :clubs))
               (legal-plays hand :led-suit nil :hearts-broken nil :leading-p t)))))

(test legal-plays-leading-can-play-hearts-once-broken
  (let ((hand (list (cons 5 :hearts) (cons 9 :clubs))))
    (is (equal hand (legal-plays hand :led-suit nil :hearts-broken t :leading-p t)))))

(test legal-plays-leading-all-hearts-hand-may-lead-hearts-unbroken
  (let ((hand (list (cons 5 :hearts) (cons 9 :hearts))))
    (is (equal hand (legal-plays hand :led-suit nil :hearts-broken nil :leading-p t)))))

;;; Trick winner

(test trick-winner-index-highest-card-of-led-suit-wins
  (let ((trick (list (cons 5 :clubs) (cons 12 :clubs) (cons 2 :hearts) (cons 9 :clubs))))
    (is (= 1 (trick-winner-index trick :clubs)))))

(test trick-winner-index-ignores-cards-not-in-led-suit
  "An ace of a DIFFERENT suit never wins the trick, no matter how high."
  (let ((trick (list (cons 3 :diamonds) (cons 14 :spades) (cons 9 :diamonds))))
    (is (= 2 (trick-winner-index trick :diamonds)))))
