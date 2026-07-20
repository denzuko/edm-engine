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

;; BDD-first, per direct correction to this session's own practice:
;; written before LINEAR-ROW-POSITION exists, expected to fail until
;; it's implemented. This is the goal gate #20 describes, not a
;; regression test added after the fact.
(test linear-row-position-is-base-offset-plus-index-times-stride
  "BASE-OFFSET + INDEX * (ITEM-SIZE + GAP) — the fixed-start, non-
centered sibling of CENTERED-ROW-POSITIONS. Checked against the
actual shape Hearts' HAND-CARD-X and Yahtzee's dice-row positioning
independently duplicate: a 20px base offset, item 0 at the base,
item N at base + N * stride."
  (is (= 20 (lrp 20 0 55 0)))
  (is (= 75 (lrp 20 1 55 0)))
  (is (= 130 (lrp 20 2 55 0))))

(test linear-row-position-treats-item-size-and-gap-as-one-combined-stride
  "ITEM-SIZE and GAP are separate parameters, but their effect is
additive -- (item-size=50, gap=5) must produce the same result as
(item-size=55, gap=0), matching how CENTERED-ROW-POSITIONS' own
stride math already works (ITEM-SIZE + GAP), not a different
convention for the fixed-start sibling."
  (is (= (lrp 20 3 55 0) (lrp 20 3 50 5))))

;; BDD-first, per #36's own open question ("anchor-to-container-edge
;; ... probably general, even though Hearts is currently the only
;; consumer") now resolved yes — written before ANCHOR-AT-EDGE exists,
;; expected to fail until implemented. Checked against Hearts'
;; existing AI-ORIGIN-POSITION values directly (not invented): a
;; fixed offset from the named edge, centered on the OTHER axis —
;; single-float throughout, matching the raylib-coordinate convention
;; this shape's actual, only consumer needs.
(test anchor-at-edge-left-fixes-x-and-centers-y
  "Hearts player 1's actual shape: 24.0 from the left edge, vertically
centered for a 62.0-tall content stack in a 768.0-tall container."
  (multiple-value-bind (x y) (anchor-at-edge :left 24.0 1024.0 768.0 0.0 62.0)
    (is (= 24.0 x))
    (is (= 353.0 y))))

(test anchor-at-edge-right-offsets-from-the-right-edge
  "Hearts player 3's actual shape: 70.0 from the right edge (so X =
container-width - offset, not just the offset itself), same vertical
centering as player 1."
  (multiple-value-bind (x y) (anchor-at-edge :right 70.0 1024.0 768.0 0.0 62.0)
    (is (= 954.0 x))
    (is (= 353.0 y))))

(test anchor-at-edge-top-fixes-y-and-centers-x
  "Hearts player 2's actual shape: 40.0 from the top edge, horizontally
centered for a 46.0-wide content stack in a 1024.0-wide container —
the perpendicular case from LEFT/RIGHT, checked independently rather
than assumed symmetric from those two alone."
  (multiple-value-bind (x y) (anchor-at-edge :top 40.0 1024.0 768.0 46.0 0.0)
    (is (= 489.0 x))
    (is (= 40.0 y))))

(test anchor-at-edge-bottom-offsets-from-the-bottom-edge
  "The fourth edge, not yet a real consumer anywhere in this codebase
but a genuine, symmetric case the primitive should still support
correctly, not just the three Hearts happens to use."
  (multiple-value-bind (x y) (anchor-at-edge :bottom 40.0 1024.0 768.0 46.0 0.0)
    (is (= 489.0 x))
    (is (= 728.0 y))))

;;; DEFLAYOUT — #36's own remaining, central scope: declaring a
;;; screen's layout as data, composing the primitives above, rather
;;; than per-screen arithmetic. BDD-first: written before DEFLAYOUT
;;; exists, expected to fail until implemented.

(test deflayout-row-defines-a-function-matching-lrp-directly
  "GOAL: a :ROW shape's generated function must compute the exact same
position LRP itself would for the same parameters — DEFLAYOUT composes
the existing primitive, it doesn't reimplement the math. Checked
against Hearts' actual HAND-CARD-X shape (20 base, 55 item-size, 0
gap), not an arbitrary example."
  (deflayout test-hand-card-x (i)
    (:row :anchor 20 :item-size 55 :gap 0 :index i))
  (is (= (lrp 20 0 55 0) (test-hand-card-x 0)))
  (is (= (lrp 20 3 55 0) (test-hand-card-x 3))))

(test deflayout-row-rejects-a-bare-nonzero-gap-literal-at-macro-expansion-time
  "GOAL: the design doc's own stated enforcement — a bare pixel literal
in :GAP position is a compile error, not a style nit caught in review.
Zero is the absence of spacing, not a spacing value, and is the one
literal explicitly allowed without resolving to the +SPACE-N+ scale —
checked as its own case above, not assumed exempt here."
  (signals error
    (macroexpand-1 '(deflayout bad-layout (i)
                      (:row :anchor 20 :item-size 55 :gap 55 :index i)))))

(test deflayout-row-accepts-a-named-space-scale-symbol-for-gap
  "The actual, intended way to specify real spacing — a +SPACE-N+
symbol, not a literal, and not rejected the way the bad-literal case
above is."
  (deflayout test-spaced-row (i)
    (:row :anchor 0 :item-size 50 :gap +space-2+ :index i))
  (is (= (lrp 0 2 50 8) (test-spaced-row 2))))
