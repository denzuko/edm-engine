(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; #37's first real slice — the stylesheet DSL, proven against Hearts'
;;; AI-avatar glyph-color (declared at the bottom of stylesheet.lisp
;;; itself, the actual retrofit, not a test-only fixture).

(test get-style-returns-the-declared-raw-value-not-a-resolved-color
  "GET-STYLE returns exactly what was declared -- (:role :info), not
an RGB triple. RESOLVE-STYLE-ROLE is the one that resolves it; keeping
them separate is deliberate, checked here explicitly."
  (is (equal '(:role :info) (get-style '(:hearts :ai-avatar) :glyph-color))))

(test resolve-style-role-matches-a-direct-theme-color-call
  "The actual point of the whole system: RESOLVE-STYLE-ROLE's result
must be identical to calling THEME-COLOR directly with the same role
-- not an approximation, the same value, since it's meant to be a
drop-in replacement for the hardcoded call it retrofits."
  (is (equal (theme-color :info) (resolve-style-role '(:hearts :ai-avatar) :glyph-color))))

(test resolve-style-role-tracks-theme-direction-changes-dynamically
  "A real, important design property, not just incidentally true:
stylesheets store the ROLE keyword, not a resolved color, specifically
so a *THEME-DIRECTION* change needs no stylesheet re-resolution at
all. Verified directly, not assumed from the implementation reading
right."
  (let ((*theme-direction* :light))
    (let ((light-color (resolve-style-role '(:hearts :ai-avatar) :glyph-color)))
      (let ((*theme-direction* :dark))
        (is (not (equal light-color (resolve-style-role '(:hearts :ai-avatar) :glyph-color))))))))

(test defstylesheet-later-declaration-wins-per-attribute-not-whole-selector
  "A second DEFSTYLESHEET for the same selector overriding one
attribute must not clobber a different attribute already declared for
that selector -- the actual 'game pack overrides without touching
core' property #37's design promises, checked directly rather than
assumed from the cascade logic reading correctly."
  (defstylesheet :test-base
    (:selector (:test :widget) :fill (:role :panel) :border (:role :accent)))
  (defstylesheet :test-override
    (:selector (:test :widget) :fill (:role :muted)))
  (is (equal '(:role :muted) (get-style '(:test :widget) :fill)))
  (is (equal '(:role :accent) (get-style '(:test :widget) :border))))

(test defstylesheet-rejects-an-invalid-role-at-macroexpansion-time
  "A typo'd role is a compile error, not a runtime EBASE-CASE failure
inside THEME-COLOR later -- checked via EVAL so the error is caught as
a test assertion rather than breaking this spec file's own
compilation, matching how macro-time validation actually manifests
(at the point something tries to expand/compile the form)."
  (signals error
    (eval '(defstylesheet :test-bad-role
             (:selector (:test :bad) :fill (:role :not-a-real-role))))))

;;; RESOLVE-STYLE-ROLE-KEYWORD — #37's design doc section 4's actual
;;; remaining gap: DRAW-CHROME-RECT's own ROLE parameter feeds its
;;; shader's HSV computation directly (a genuinely GPU-driven color,
;;; not a pre-resolved RGB) -- checked directly in RENDER.LISP, not
;;; assumed. RESOLVE-STYLE-ROLE (above) resolves (:ROLE X) to an RGB
;;; triple, the wrong shape for this case; this returns just the role
;;; KEYWORD a stylesheet declared, so a shader-driven caller like
;;; DRAW-CHROME-RECT can pass it straight through to its own THEME-HSV
;;; call, the actual style-attribute-to-shader-parameter wiring the
;;; design doc names, not built speculatively without this real case.

(test resolve-style-role-keyword-returns-just-the-keyword-not-a-color
  "GOAL: unlike RESOLVE-STYLE-ROLE, this must NOT resolve to an RGB
value -- a shader-driven caller needs the role itself to do its own
GPU-side HSV computation, not a CPU-resolved color that would defeat
the whole point of a GPU-driven shader."
  (defstylesheet :test-shader-role
    (:selector (:test :shader-target) :fill (:role :accent)))
  (is (eq :accent (resolve-style-role-keyword '(:test :shader-target) :fill))))
