(in-package :edm-engine/audio/tests)
(in-suite :edm-engine-audio)

(test note-frequency-a4-is-440
  (is (< (abs (- 440.0 (note-frequency 0))) 0.01)))

(test note-frequency-octave-up-doubles
  (is (< (abs (- 880.0 (note-frequency 12))) 0.01)))

(test note-frequency-octave-down-halves
  (is (< (abs (- 220.0 (note-frequency -12))) 0.01)))

(test mix-samples-sums-multiple-channels
  (let ((a (make-array 4 :element-type '(signed-byte 16) :initial-contents '(1000 -1000 500 -500)))
        (b (make-array 4 :element-type '(signed-byte 16) :initial-contents '(1000 1000 -500 -500))))
    (is (equalp #(2000 0 0 -1000) (mix-samples (list a b))))))

(test mix-samples-clamps-to-int16-range
  (let ((a (make-array 2 :element-type '(signed-byte 16) :initial-contents '(30000 -30000)))
        (b (make-array 2 :element-type '(signed-byte 16) :initial-contents '(30000 -30000))))
    (is (equalp #(32767 -32768) (mix-samples (list a b))))))

(test mix-samples-single-channel-is-unchanged
  (let ((a (make-array 3 :element-type '(signed-byte 16) :initial-contents '(1 2 3))))
    (is (equalp #(1 2 3) (mix-samples (list a))))))

(test render-pattern-produces-one-row-duration-of-silence-for-an-empty-row
  (let* ((pattern (list (list nil nil)))   ; one row, two channels, both silent
         (samples (render-pattern pattern 0.1 :sample-rate 1000)))
    (is (= 100 (length samples)))
    (is (every #'zerop samples))))

(test render-pattern-plays-a-note-when-a-channel-has-one
  (let* ((pattern (list (list (cons 0 :sine))))  ; one row, one channel, A4 sine
         (samples (render-pattern pattern 0.1 :sample-rate 1000)))
    (is (= 100 (length samples)))
    (is (some (lambda (s) (/= 0 s)) samples))))

(test render-pattern-concatenates-multiple-rows
  (let* ((pattern (list (list (cons 0 :sine)) (list (cons 12 :square))))
         (samples (render-pattern pattern 0.05 :sample-rate 1000)))
    (is (= 100 (length samples))))) ; 2 rows * 0.05s * 1000Hz = 100

(test render-pattern-mixes-simultaneous-channels
  "Two channels playing at once in the same row should differ from
either channel playing alone — a real mix, not just the last channel
overwriting the others."
  (let* ((one-channel (render-pattern (list (list (cons 0 :sine))) 0.05 :sample-rate 1000))
         (two-channel (render-pattern (list (list (cons 0 :sine) (cons 12 :sine))) 0.05 :sample-rate 1000)))
    (is (not (equalp one-channel two-channel)))))

(test theme-playback-decision-cache-hit-wins-regardless-of-other-state
  "A cache hit should short-circuit everything else — even if a stale
PENDING flag or a leftover bus message somehow exist, an already-
cached sound should just play, not re-trigger async work."
  (is (eq :play-cached (theme-playback-decision t nil nil)))
  (is (eq :play-cached (theme-playback-decision t t t))))

(test theme-playback-decision-starts-async-work-exactly-once
  "No cache, nothing pending yet — start the async task. This is the
branch that must fire only once per key, not the state machine's own
job (ENSURE-THEME-SOUND-ASYNC's caller sets the PENDING flag before
this decision is next consulted for the same key)."
  (is (eq :start-async (theme-playback-decision nil nil nil))))

(test theme-playback-decision-waits-while-pending-and-not-ready
  (is (eq :wait (theme-playback-decision nil t nil))))

(test theme-playback-decision-wraps-and-plays-once-samples-arrive
  (is (eq :wrap-and-play (theme-playback-decision nil t t))))

(test render-pattern-async-produces-the-same-samples-as-the-synchronous-version
  "A real integration test, not just the pure decision logic — kicks
off the actual LPARALLEL/bus pipeline and confirms it genuinely
delivers the same PCM data RENDER-PATTERN would produce synchronously,
not just that some samples arrive."
  (let* ((pattern (list (list (cons 0 :sine))))
         (bus (edm-engine:make-bus))
         (expected (render-pattern pattern 0.05 :sample-rate 44100)))
    (render-pattern-async pattern 0.05 bus :test-theme :amplitude 0.5)
    (let ((actual (edm-engine:bus-pop bus :test-theme)))
      (is (equalp expected actual)))))
