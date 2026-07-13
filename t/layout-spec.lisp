(in-package :edm-engine/tests)
(in-suite :edm-engine)

(test centered-row-positions-single-item-is-centered
  (is (equal '(475) (centered-row-positions 1 50 20 1000))))

(test centered-row-positions-multiple-items-evenly-spaced
  "3 items, 100 wide, 20 gap, in a 1000-wide container: total content
width = 3*100 + 2*20 = 340, so it starts at (1000-340)/2 = 330, and
each subsequent item is 100+20=120 further right."
  (is (equal '(330 450 570) (centered-row-positions 3 100 20 1000))))

(test centered-row-positions-zero-items-is-empty
  (is (equal nil (centered-row-positions 0 50 20 1000))))

(test wrap-text-lines-fits-on-one-line-when-short
  (is (equal '("hello world")
              (wrap-text-lines "hello world" (lambda (s) (length s)) 20))))

(test wrap-text-lines-breaks-at-word-boundaries
  (is (equal '("one two" "three four")
              (wrap-text-lines "one two three four" (lambda (s) (length s)) 10))))

(test wrap-text-lines-never-splits-a-single-word-mid-word
  "A word longer than the budget still goes on its own line whole,
rather than being cut mid-word."
  (is (equal '("averylongword")
              (wrap-text-lines "averylongword" (lambda (s) (length s)) 5))))

(test wrap-text-lines-empty-string-is-no-lines
  (is (equal nil (wrap-text-lines "" (lambda (s) (length s)) 20))))
