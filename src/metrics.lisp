(in-package :edm-engine)

;;; #51's metrics/observability system — first real implementation
;;; slice, scoped against #50's actual investigation (bus/thread
;;; offloading, memory management "in the first few cycles") rather
;;; than the full instrumentation list in the design doc at once.
;;; Genuinely pure (no raylib dependency) — belongs in the tested core,
;;; same discipline that moved #23's LOG-CRASH and #22's
;;; THEME-PLAYBACK-DECISION there.
;;;
;;; Named per docs/naming-convention.md (token-golfed, measured not
;;; guessed) — explicit :CONC-NAME/:CONSTRUCTOR overrides below because
;;; DEFSTRUCT's own defaults insert a hyphen (MAKE-, STRUCTNAME-) that
;;; the convention exists specifically to avoid.

(defstruct (mCounter (:constructor mkMCounter) (:conc-name mCounter))
  (value 0 :type (unsigned-byte 64)))

(defstruct (mGauge (:constructor mkMGauge) (:conc-name mGauge))
  (value 0.0d0 :type double-float))

(defstruct (mHist (:constructor mkMHist) (:conc-name mHist))
  "Deliberately simple — running count/sum/min/max, not full
percentile buckets. This genre's actual debugging need (#50's own
investigation) is 'what's the average and worst case', not
percentile-accurate distributions a real APM tool would need."
  (count 0 :type (unsigned-byte 64))
  (sum 0.0d0 :type double-float)
  (min nil :type (or null double-float))
  (max nil :type (or null double-float)))

(defvar *metrics* (make-hash-table :test #'equal)
  "tag-string -> MCOUNTER/MGAUGE/MHIST. A plain global hash table,
deliberately — SWANK-queryable directly, the same live-inspection
pattern this session's own verification work already relies on (#22's
async theme check, #23's injected-error test, #30's live difficulty
check), no new tooling required for that path.")

(declaim (ftype (function (string &optional (unsigned-byte 64)) (unsigned-byte 64)) mInc))
(defun mInc (tag &optional (amount 1))
  "mInc = metric increment. Increments TAG's counter, creating it at
zero first if this is the first observation. O(1) — one hash lookup,
one slot update — cheap enough not to distort what it measures.
Genuinely hot (every bus push/pop, per #22's instrumentation below),
hence the acronym per the naming convention's own stated bar."
  (let ((counter (or (gethash tag *metrics*)
                      (setf (gethash tag *metrics*) (mkMCounter)))))
    (incf (mCounterValue counter) amount)))

(declaim (ftype (function (string double-float) double-float) mGaugeSet))
(defun mGaugeSet (tag value)
  "Sets TAG's gauge to VALUE directly — a gauge is a point-in-time
reading ('what is X right now'), not accumulated, unlike a counter or
histogram. Hot (every bus push/pop), same rationale as MINC."
  (let ((gauge (or (gethash tag *metrics*)
                    (setf (gethash tag *metrics*) (mkMGauge)))))
    (setf (mGaugeValue gauge) value)))

(declaim (ftype (function (string double-float) double-float) mObs))
(defun mObs (tag value)
  "mObs = metric observe. Records one observation into TAG's
histogram, creating it first if needed. Hot — called by WTMR on every
timed operation, including every frame's render time."
  (let ((hist (or (gethash tag *metrics*)
                   (setf (gethash tag *metrics*) (mkMHist)))))
    (incf (mHistCount hist))
    (incf (mHistSum hist) value)
    (setf (mHistMin hist)
          (if (mHistMin hist) (min (mHistMin hist) value) value))
    (setf (mHistMax hist)
          (if (mHistMax hist) (max (mHistMax hist) value) value))
    value))

(defun mHistMean (hist)
  "NIL if no observations yet, not a division-by-zero error — a real
edge case (a metric that's been registered but never actually
observed, e.g. queried mid-startup before the first event). Called
only for reporting (DUMPMETRICS), not per-frame — full camelCase, not
acronym-tier, per the convention's own default."
  (when (plusp (mHistCount hist))
    (/ (mHistSum hist) (mHistCount hist))))

(defmacro wTmr (tag &body body)
  "wTmr = with timer. Wraps BODY, records its wall-clock duration
(seconds, double-float) as a histogram observation against TAG. The
actual instrumentation primitive most consumers use directly, rather
than hand-timing with GET-INTERNAL-REAL-TIME at each call site — the
exact ad hoc pattern #50's own investigation had to fall back on.
Genuinely hot (wraps the per-frame render call in MAIN.LISP), hence
the acronym."
  (let ((start (gensym "START")))
    `(let ((,start (get-internal-real-time)))
       (multiple-value-prog1 (progn ,@body)
         (mObs ,tag (float (/ (- (get-internal-real-time) ,start)
                               internal-time-units-per-second)
                            1.0d0))))))

(defun clearMetrics ()
  "Resets the registry — real test isolation for anything that checks
metric values, not a production feature. Test-only, called rarely —
full camelCase, not acronym-tier."
  (clrhash *metrics*))

;;; GC instrumentation — SB-EXT:*AFTER-GC-HOOKS* and
;;; SB-EXT:*GC-RUN-TIME*/SB-KERNEL:DYNAMIC-USAGE are real, verified
;;; SBCL mechanisms (checked directly before writing this), not
;;; invented. Directly answers #50's "memory management" concern,
;;; which this session had zero prior instrumentation for.

(defvar *lastGcRunTime* 0
  "Tracks SB-EXT:*GC-RUN-TIME*'s previous cumulative value, so each
hook invocation records this GC's own duration (the delta), not the
running total re-observed on every collection.")

(defun recordGcMetrics ()
  "Called once per GC — not per-frame, so full camelCase rather than
acronym-tier; GC frequency doesn't approach the per-frame bar."
  (mInc "gc.run_count")
  (let ((delta (- sb-ext:*gc-run-time* *lastGcRunTime*)))
    (setf *lastGcRunTime* sb-ext:*gc-run-time*)
    (mObs "gc.time_spent" (float (/ delta internal-time-units-per-second) 1.0d0)))
  (mGaugeSet "gc.bytes_allocated" (float (sb-kernel:dynamic-usage) 1.0d0)))

(defun installGcHook ()
  "Idempotent — checking membership first avoids double-installing if
called more than once from different entry points (MAIN, a REPL, a
test fixture). Called once at startup — full camelCase."
  (pushnew 'recordGcMetrics sb-ext:*after-gc-hooks*))

(defparameter *metricsLogPath*
  (merge-pathnames ".parencade-saves/metrics.log" (user-homedir-pathname))
  "Sibling to *CRASHLOGPATH*/*SAVE-DIRECTORY* — diagnostic data, not
game state.")

(defun dumpMetrics ()
  "For when a live SWANK session isn't attached — a real player on
real (possibly weak, per #50) hardware can report a metrics snapshot
alongside a bug report without a developer needing to be connected at
the time. Best-effort, same rationale as LOGCRASH: a failure to write
this should never become a second, more confusing failure. Called
rarely (on demand) — full camelCase."
  (ignore-errors
    (ensure-directories-exist *metricsLogPath*)
    (with-open-file (out *metricsLogPath* :direction :output
                                           :if-exists :supersede
                                           :if-does-not-exist :create)
      (format out "~&[~A]~%" (get-universal-time))
      (maphash
       (lambda (tag metric)
         (etypecase metric
           (mCounter (format out "~A = ~A (counter)~%" tag (mCounterValue metric)))
           (mGauge (format out "~A = ~A (gauge)~%" tag (mGaugeValue metric)))
           (mHist
            (format out "~A: count=~A sum=~A mean=~A min=~A max=~A (histogram)~%"
                    tag (mHistCount metric) (mHistSum metric)
                    (mHistMean metric) (mHistMin metric) (mHistMax metric)))))
       *metrics*))))
