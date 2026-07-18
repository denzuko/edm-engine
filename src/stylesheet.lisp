(in-package :edm-engine)

;;; #37's stylesheet DSL — first real slice of the VFX/style pipeline
;;; design, proven against one real retrofit (Hearts' AI-avatar glyph-
;;; color, one of the two candidates the design doc itself named)
;;; before being treated as settled. Deliberately scoped to just this
;;; piece — the event bus/effect-instance/arena parts of #37 stay
;;; unimplemented until this piece is proven.

(defvar *stylesheets* (make-hash-table :test #'equal)
  "selector (a list of keywords, e.g. (:hearts :ai-avatar)) -> resolved
attribute plist. Populated by DEFSTYLESHEET forms at load time.
Last-loaded-wins per *attribute*, not per selector — a game pack can
override one attribute of a selector without clobbering the others
declared elsewhere, matching the design doc's own 'no core file
edited' game-pack-override example.")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun validate-style-value (attr value)
    "Macro-time validation, called from DEFSTYLESHEET's expansion —
(:role X) must name a real +THEME-COLOR-ROLES+ member; a typo'd role
is a compile error here, not a runtime EBASE-CASE failure inside
THEME-COLOR later. Other attribute shapes (bare numbers, etc.) pass
through unvalidated for now — :space-scale validation is real, scoped
follow-on work once a selector that actually needs it gets retrofitted,
not built speculatively ahead of a real consumer.

EVAL-WHEN is required, not decorative — this function runs during
DEFSTYLESHEET's own macro expansion (at compile time), so a plain
DEFUN wouldn't be visible to the compiler when it processes a
DEFSTYLESHEET form in the same compilation unit."
    (when (and (consp value) (eq (first value) :role))
      (unless (member (second value) +theme-color-roles+)
        (error "DEFSTYLESHEET: ~S is not a valid role for attribute ~S (must be one of ~S)"
               (second value) attr +theme-color-roles+)))
    value))

(defun register-stylesheet-selector (selector attrs)
  "New ATTRS are prepended, not appended — GETF (via GET-STYLE) scans
left to right and returns the first match, so a later
REGISTER-STYLESHEET-SELECTOR call for the same selector correctly wins
per-attribute, the actual last-loaded-wins cascade, not a whole-
selector overwrite."
  (setf (gethash selector *stylesheets*)
        (append attrs (gethash selector *stylesheets*))))

(defmacro defstylesheet (name &body selector-clauses)
  "NAME is a keyword identifying this stylesheet (informational —
which pack declared these selectors, for debugging; load order is
textual definition order, not NAME-based). Each clause:
(:selector (tag...) :attr1 val1 :attr2 val2 ...).

S-expressions, not JSON or a separate runtime format — validated at
compile time via VALIDATE-STYLE-VALUE, the same principle #32
established for the float-precision class of bug, applied here to
style tokens instead."
  (declare (ignore name))
  `(progn
     ,@(loop for clause in selector-clauses
             collect
             (destructuring-bind (selector-tag selector-tags &rest attrs) clause
               (declare (ignore selector-tag))
               (loop for (attr val) on attrs by #'cddr
                     do (validate-style-value attr val))
               `(register-stylesheet-selector ',selector-tags ',attrs)))))

(declaim (ftype (function (list keyword) t) get-style))
(defun get-style (selector attr)
  "O(1) lookup — resolved once at DEFSTYLESHEET load time (a single
hash-table access plus a short plist scan, not a per-frame cascade
walk), matching #37's governing performance discipline. Returns the
raw declared value (e.g. (:role :accent)), not a resolved color —
RESOLVE-STYLE-ROLE does that conversion, kept separate so GET-STYLE
stays generic across attribute types, not color-specific."
  (getf (gethash selector *stylesheets*) attr))

(declaim (ftype (function (list keyword) t) resolve-style-role))
(defun resolve-style-role (selector attr)
  "Convenience for the common (:role X) case — returns the actual RGB
THEME-COLOR gives for X right now, dynamically, not a value cached at
stylesheet-load time. This is why stylesheets store the role keyword
and not a resolved color: a theme change (*THEME-DIRECTION*) needs no
stylesheet re-resolution at all — THEME-COLOR already handles that
dynamically, the same as every other role-based color lookup already
in this engine, composed rather than duplicated."
  (let ((value (get-style selector attr)))
    (if (and (consp value) (eq (first value) :role))
        (theme-color (second value))
        value)))

;;; The actual first real retrofit — Hearts' AI-avatar glyph-color,
;;; hardcoded to (THEME-COLOR :INFO) before this, now declared as data.
(defstylesheet :core
  (:selector (:hearts :ai-avatar)
    :glyph-color (:role :info)))
