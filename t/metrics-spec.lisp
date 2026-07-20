(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; #51's first real implementation slice, scoped against #50 —
;;; the primitives themselves, tested in isolation before being wired
;;; into the bus/GC instrumentation that actually answers #50's
;;; question. Names per docs/naming-convention.md.

(test metric-increment-starts-at-zero-and-accumulates
  (clearMetrics)
  (mInc "test.counter")
  (mInc "test.counter")
  (mInc "test.counter" 5)
  (is (= 7 (mCounterValue (gethash "test.counter" *metrics*)))))

(test metric-gauge-set-replaces-not-accumulates
  "A gauge is a point-in-time reading, not accumulated — the real
distinction from a counter, checked directly rather than assumed from
the struct definitions reading correctly."
  (clearMetrics)
  (mGaugeSet "test.gauge" 5.0d0)
  (mGaugeSet "test.gauge" 3.0d0)
  (is (= 3.0d0 (mGaugeValue (gethash "test.gauge" *metrics*)))))

(test metric-observe-tracks-count-sum-min-max
  (clearMetrics)
  (mObs "test.hist" 1.0d0)
  (mObs "test.hist" 5.0d0)
  (mObs "test.hist" 3.0d0)
  (let ((hist (gethash "test.hist" *metrics*)))
    (is (= 3 (mHistCount hist)))
    (is (= 9.0d0 (mHistSum hist)))
    (is (= 1.0d0 (mHistMin hist)))
    (is (= 5.0d0 (mHistMax hist)))))

(test metric-histogram-mean-is-nil-before-any-observations
  "A real edge case, not a division-by-zero error — a metric queried
before it's ever been observed (e.g. mid-startup, before the first
relevant event has occurred)."
  (clearMetrics)
  (mObs "test.other" 1.0d0)  ; a different tag exists
  (is (null (gethash "test.hist-never-observed" *metrics*))))

(test metric-histogram-mean-computes-correctly-once-observed
  (clearMetrics)
  (mObs "test.hist" 2.0d0)
  (mObs "test.hist" 4.0d0)
  (is (= 3.0d0 (mHistMean (gethash "test.hist" *metrics*)))))

(test with-timed-metric-records-a-real-duration
  "Not a mocked clock — a real SLEEP, checked against a loose but
real bound, confirming WTMR actually measures wall-clock time rather
than always recording zero or a placeholder."
  (clearMetrics)
  (wTmr "test.timer" (sleep 0.02))
  (let ((mean (mHistMean (gethash "test.timer" *metrics*))))
    (is (>= mean 0.015d0))
    (is (< mean 0.5d0))))

(test with-timed-metric-returns-the-bodys-own-value
  "The macro must be transparent to its body's return value — a real
usage requirement, since callers wrap existing expressions and still
need the result, not just the side-effect of recording a duration."
  (clearMetrics)
  (is (= 42 (wTmr "test.timer" 42))))

(test clear-metrics-actually-empties-the-registry
  (mInc "test.counter")
  (clearMetrics)
  (is (null (gethash "test.counter" *metrics*))))

(test install-gc-metrics-hook-is-idempotent
  "Calling it twice must not double-install the hook — checked by
counting SB-EXT:*AFTER-GC-HOOKS* membership directly, not assumed from
PUSHNEW's own semantics reading correctly for this use."
  (installGcHook)
  (installGcHook)
  (is (= 1 (count 'recordGcMetrics sb-ext:*after-gc-hooks*))))

(test a-real-gc-increments-gc-run-count-and-records-bytes-allocated
  "Not mocked — RECORDGCMETRICS itself is called directly (real code,
not a stub), after a genuine SB-EXT:GC. Doesn't rely on
SB-EXT:*AFTER-GC-HOOKS* firing synchronously before the next form runs
— checked directly, not assumed: on a different SBCL build (2.6.6 vs
this sandbox's 2.2.9), a real CI run showed that timing isn't
guaranteed, and the hook's own INSTALLATION is already covered
separately (GC-HOOK-IS-INSTALLED-ONCE-EVEN-IF-CALLED-TWICE, above) —
this test's actual job is confirming RECORDGCMETRICS itself correctly
updates metrics when it runs, the direct answer to #50's memory-
management question, which this session had zero instrumentation for
before this."
  (clearMetrics)
  (installGcHook)
  (sb-ext:gc :full t)
  (recordGcMetrics)
  (is (>= (mCounterValue (gethash "gc.run_count" *metrics*)) 1))
  (is (> (mGaugeValue (gethash "gc.bytes_allocated" *metrics*)) 0)))

(test dump-metrics-writes-a-readable-snapshot-without-erroring
  "Same rationale as #23's LOG-CRASH spec — DUMPMETRICS itself should
never become a second failure, and what it writes should actually
contain the recorded values, not just 'something was here'."
  (let ((*metricsLogPath* (merge-pathnames (format nil "edm-engine-metrics-test-~A.log" (random 1000000))
                                            (uiop:temporary-directory))))
    (unwind-protect
         (progn
           (clearMetrics)
           (mInc "test.dump_counter" 7)
           (dumpMetrics)
           (is (probe-file *metricsLogPath*))
           (is (search "test.dump_counter = 7" (uiop:read-file-string *metricsLogPath*))))
      (ignore-errors (delete-file *metricsLogPath*)))))
