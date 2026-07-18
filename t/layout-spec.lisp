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

(test centered-grid-positions-composes-centered-row-positions-per-axis
  "The 2D sibling should genuinely compose the existing 1D primitive
per axis, not reimplement the centering math — checking both axes
independently against what CENTERED-ROW-POSITIONS itself would return
for the same parameters, not just a hand-computed expected value."
  (multiple-value-bind (rows cols) (centered-grid-positions 3 2 60 60 4 4 200 100)
    (is (equal (centered-row-positions 3 60 4 100) rows))
    (is (equal (centered-row-positions 2 60 4 200) cols))))

(test centered-grid-positions-square-grid-matches-queens-shape
  "Queens' actual retrofit case — a square grid, uniform cell size,
uniform gap on both axes."
  (multiple-value-bind (rows cols) (centered-grid-positions 8 8 60 60 4 4 700 700)
    (is (= 8 (length rows)))
    (is (= 8 (length cols)))
    (is (equal rows cols)) ; square grid, square container -> identical axes
    (is (every #'plusp rows))))

(test center-within-centers-a-smaller-element-in-a-larger-container
  (multiple-value-bind (x y) (center-within 0 0 60 60 20 20)
    (is (= 20 x))
    (is (= 20 y))))

(test center-within-respects-a-nonzero-container-origin
  "The formula must add the container's own offset, not just center
within (0,0) — a real bug this shape would have if CONTAINER-X/Y were
dropped, matching how Queens' cells are never actually at the screen
origin."
  (multiple-value-bind (x y) (center-within 100 50 60 60 20 20)
    (is (= 120 x))
    (is (= 70 y))))
