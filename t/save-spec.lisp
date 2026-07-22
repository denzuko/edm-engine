(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; SAVE.LISP had zero test coverage before this file — checked
;;; directly (no t/save-spec.lisp existed anywhere). *SAVE-DIRECTORY*
;;; is rebound to a real temp directory per test, not mocked, so these
;;; genuinely exercise real file I/O.

(defmacro with-temp-save-directory (&body body)
  `(let ((*save-directory* (merge-pathnames (format nil "edm-engine-save-test-~A/" (random 1000000))
                                             (uiop:temporary-directory))))
     (unwind-protect (progn ,@body)
       (ignore-errors (uiop:delete-directory-tree *save-directory* :validate t)))))

(defclass spec-save-game () ((data :initarg :data :accessor spec-save-game-data)))
(defmethod game-save-data ((g spec-save-game)) (spec-save-game-data g))

(test save-game-to-slot-then-load-round-trips-exactly
  "GOAL: what SAVE-GAME-TO-SLOT writes is exactly what LOAD-GAME-FROM-
SLOT reads back — the basic contract every other spec here assumes
holds."
  (with-temp-save-directory
    (save-game-to-slot 0 "Queens" (make-instance 'spec-save-game :data 100) 42)
    (multiple-value-bind (title score timestamp data) (load-game-from-slot 0)
      (declare (ignore timestamp))
      (is (string= "Queens" title))
      (is (= 42 score))
      (is (= 100 data)))))

(test load-game-from-slot-returns-nil-for-a-genuinely-empty-slot
  (with-temp-save-directory
    (is (null (load-game-from-slot 5)))))

;;; #9's remaining scope — LOAD-GAME-FROM-SLOT had zero error handling:
;;; a corrupted or malformed save file threw an unhandled reader error,
;;; and since LIST-SAVE-SLOTS calls this for every slot, one bad file
;;; broke browsing every slot, not just the corrupted one. BDD-first,
;;; written before the fix exists.

(test load-game-from-slot-does-not-signal-on-a-genuinely-corrupted-file
  "GOAL: a real, malformed sexp (unbalanced parens, truncated mid-
write — a real failure mode, not a contrived one) must not signal an
unhandled error, matching the existing NIL-for-empty-slot contract
rather than a new, special error path the rest of the code would need
its own handling for. Uses FINISHES, not a local IGNORE-ERRORS wrapper
around the call — a local wrapper would mask whether LOAD-GAME-FROM-
SLOT itself handles the error, making the test pass regardless of
whether the fix exists, a real flaw caught in this test's own first
draft before it was run."
  (with-temp-save-directory
    (ensure-save-directory)
    (with-open-file (out (save-slot-data-path 0) :direction :output :if-does-not-exist :create)
      (write-string "(:table-title \"Queens\" :score 5 :data (" out)) ; deliberately truncated, unbalanced parens
    (finishes (load-game-from-slot 0))))

(test load-game-from-slot-returns-nil-not-a-partial-value-on-a-corrupted-file
  "GOAL: a corrupted slot behaves exactly like an empty one to every
caller — LIST-SAVE-SLOTS' own NIL-means-empty convention, not a
different, special case it would need to check for separately."
  (with-temp-save-directory
    (ensure-save-directory)
    (with-open-file (out (save-slot-data-path 0) :direction :output :if-does-not-exist :create)
      (write-string "not even a valid sexp at all }{" out))
    (is (null (load-game-from-slot 0)))))

(test list-save-slots-skips-a-corrupted-slot-rather-than-breaking-every-other-slot
  "GOAL: the actual real-world impact of the bug this fixes — one
corrupted slot must not prevent the other, genuinely valid slots from
listing correctly, checked as the real, combined scenario rather than
LOAD-GAME-FROM-SLOT's own contract assumed to compose correctly."
  (with-temp-save-directory
    (save-game-to-slot 0 "Queens" (make-instance 'spec-save-game :data 1) 10)
    (ensure-save-directory)
    (with-open-file (out (save-slot-data-path 1) :direction :output :if-does-not-exist :create)
      (write-string "(:corrupted" out))
    (save-game-to-slot 2 "Hearts" (make-instance 'spec-save-game :data 2) 20)
    (let ((slots (list-save-slots)))
      (is (getf (nth 0 slots) :table-title))
      (is (null (nth 1 slots)))
      (is (getf (nth 2 slots) :table-title)))))

;;; #9's remaining scope — save integrity checking. SXHASH, not a
;;; cryptographic HMAC: the actual threat model here is accidental
;;; corruption (a partial write, a disk error, a hand-edited file with
;;; a typo), not a malicious actor with write access to the save file
;;; -- anyone with that access could forge any checksum this code
;;; computed anyway, so a full crypto dependency buys nothing real
;;; here. BDD-first, written before the checksum field exists.

(test save-game-to-slot-writes-a-checksum-that-load-game-from-slot-verifies
  "GOAL: a save written by SAVE-GAME-TO-SLOT itself must load back
cleanly -- the checksum mechanism must not break the ordinary,
uncorrupted case it's meant to protect."
  (with-temp-save-directory
    (save-game-to-slot 0 "Queens" (make-instance 'spec-save-game :data 100) 42)
    (multiple-value-bind (title score timestamp data) (load-game-from-slot 0)
      (declare (ignore timestamp))
      (is (string= "Queens" title))
      (is (= 42 score))
      (is (= 100 data)))))

(test load-game-from-slot-returns-nil-when-the-data-has-been-tampered-with
  "GOAL: a save file whose :DATA has been altered after writing (a
real corruption scenario a checksum specifically exists to catch,
distinct from the malformed-sexp case above) must be rejected, not
silently trusted."
  (with-temp-save-directory
    (save-game-to-slot 0 "Queens" (make-instance 'spec-save-game :data 100) 42)
    (let ((path (save-slot-data-path 0)))
      (let ((saved (with-open-file (in path) (read in))))
        (with-open-file (out path :direction :output :if-exists :supersede)
          (prin1 (append (list :data 999) (alexandria:remove-from-plist saved :data)) out))))
    (is (null (load-game-from-slot 0)))))

;;; DEFSAVE-DATA — #58's own real finding: GAME-SAVE-DATA's own shape
;;; (build a plist of :field (accessor game) pairs) is genuinely
;;; identical across all four games, checked directly — only the
;;; field names differ, zero real variation in the mechanism itself.
;;; RESTORE-*-GAME stays hand-written (Queens' own regenerate-then-
;;; restore-progress shape genuinely differs from the other three's
;;; direct-construction shape — a real structural difference, not
;;; forced into one macro just because half of the pair is
;;; mechanical). BDD-first, written before DEFSAVE-DATA exists.

(defstruct spec-macro-game field-a field-b field-c)

(test defsave-data-generates-a-game-save-data-method-matching-manual-construction
  "GOAL: the generated method must produce exactly what hand-writing
(LIST :FIELD-A (SPEC-MACRO-GAME-FIELD-A GAME) ...) would — composing
accessor calls via the field list, not a different mechanism."
  (defsave-data spec-macro-game :field-a :field-b :field-c)
  (let ((game (make-spec-macro-game :field-a 1 :field-b 2 :field-c 3)))
    (is (equal (list :field-a 1 :field-b 2 :field-c 3) (game-save-data game)))))

(test defsave-data-uses-the-struct-prefixed-accessor-name-directly
  "GOAL: the accessor name is derived from the struct name and field
name directly (SPEC-MACRO-GAME-FIELD-A, DEFSTRUCT's own default
convention) -- checked with a struct whose fields are genuinely
distinct values, not coincidentally identical ones a bug could hide
behind."
  (defsave-data spec-macro-game :field-a :field-b :field-c)
  (let ((game (make-spec-macro-game :field-a :x :field-b :y :field-c :z)))
    (is (equal (list :field-a :x :field-b :y :field-c :z) (game-save-data game)))))

;;; SAVE-SLOT-DATA — the low-level writer SAVE-GAME-TO-SLOT itself now
;;; composes. Split out per direct correction: the actual "Save State"
;;; UI flow calls SAVE-GAME-TO-SLOT (which computes GAME-SAVE-DATA)
;;; and RAYLIB:TAKE-SCREENSHOT directly and synchronously in the same
;;; key-handler — the exact direct-call pattern #37's own bus-driven
;;; VFX trigger was built to replace, never applied to save-game
;;; itself. The real fix needs a :SAVE-GAME bus event carrying already-
;;; computed GAME-SAVE-DATA (computed at push time, while the game
;;; object is still current) to a consumer that writes it — this
;;; function is that consumer's own write step, independent of
;;; SAVE-GAME-TO-SLOT's own game-object-taking convenience wrapper.

(test save-slot-data-writes-pre-computed-data-without-needing-a-game-object
  "GOAL: the bus consumer receives already-computed GAME-SAVE-DATA (the
event payload), not a game object — SAVE-SLOT-DATA must accept that
data directly and produce the identical file SAVE-GAME-TO-SLOT itself
would, not a different format the loader would need special-casing
for."
  (with-temp-save-directory
    (save-slot-data 0 "Queens" 100 42)
    (multiple-value-bind (title score timestamp data) (load-game-from-slot 0)
      (declare (ignore timestamp))
      (is (string= "Queens" title))
      (is (= 42 score))
      (is (= 100 data)))))

(test save-game-to-slot-composes-save-slot-data-not-a-separate-implementation
  "GOAL: SAVE-GAME-TO-SLOT (the existing, game-object-taking
convenience wrapper still used by ARCADE-SAVE-CURRENT for any direct,
synchronous caller) and SAVE-SLOT-DATA (the new, data-taking consumer
entry point) must produce byte-identical files for equivalent inputs —
one real implementation underneath two calling conventions, not two
separately-maintained write paths that could silently drift apart."
  (with-temp-save-directory
    (save-game-to-slot 0 "Queens" (make-instance 'spec-save-game :data 100) 42)
    (let ((via-wrapper (uiop:read-file-string (save-slot-data-path 0))))
      (with-temp-save-directory
        (save-slot-data 0 "Queens" 100 42)
        ;; Timestamps will genuinely differ (real GET-UNIVERSAL-TIME
        ;; calls, not injectable) -- compare everything else.
        (let ((via-consumer (uiop:read-file-string (save-slot-data-path 0))))
          (flet ((strip-timestamp (s)
                   (let* ((plist (read-from-string s))
                          (stripped (copy-list plist)))
                     (remf stripped :timestamp)
                     stripped)))
            (is (equal (strip-timestamp via-wrapper) (strip-timestamp via-consumer)))))))))
