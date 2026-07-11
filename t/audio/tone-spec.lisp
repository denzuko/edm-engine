(defpackage :edm-engine/audio/tests
  (:use :cl :fiveam :edm-engine/audio))
(in-package :edm-engine/audio/tests)

(def-suite :edm-engine-audio)
(in-suite :edm-engine-audio)

(test generate-samples-produces-correct-sample-count
  (let ((samples (generate-samples :sine 440.0 0.5 :sample-rate 44100)))
    (is (= 22050 (length samples)))))

(test generate-samples-stays-within-int16-range
  (let ((samples (generate-samples :sine 440.0 0.1 :amplitude 0.9)))
    (is (every (lambda (s) (<= -32768 s 32767)) samples))))

(test generate-samples-sine-peak-matches-amplitude
  (let* ((samples (generate-samples :sine 100.0 1.0 :sample-rate 44100 :amplitude 0.5))
         (peak (reduce #'max samples :key #'abs)))
    ;; peak should land close to amplitude * 32767, within one period's
    ;; worth of sampling granularity
    (is (> peak (round (* 0.45 32767))))
    (is (<= peak (round (* 0.5 32767))))))

(test generate-samples-square-wave-only-takes-two-values
  (let* ((samples (generate-samples :square 220.0 0.05 :amplitude 0.6))
         (distinct (remove-duplicates (coerce samples 'list))))
    (is (= 2 (length distinct)))))

(test generate-samples-silent-at-zero-amplitude
  (let ((samples (generate-samples :sine 440.0 0.01 :amplitude 0.0)))
    (is (every #'zerop samples))))

(test wav-bytes-for-samples-produces-a-valid-riff-header
  (let* ((samples (generate-samples :sine 440.0 0.01))
         (bytes (wav-bytes-for-samples samples 44100)))
    (is (typep bytes '(array (unsigned-byte 8) (*))))
    (is (string= "RIFF" (map 'string #'code-char (subseq bytes 0 4))))
    (is (string= "WAVE" (map 'string #'code-char (subseq bytes 8 12))))
    (is (string= "data" (map 'string #'code-char (subseq bytes 36 40))))))

(test wav-bytes-declared-size-matches-sample-data
  (let* ((samples (generate-samples :sine 440.0 0.01))
         (bytes (wav-bytes-for-samples samples 44100))
         (data-chunk-size (+ (ash (aref bytes 40) 0) (ash (aref bytes 41) 8)
                              (ash (aref bytes 42) 16) (ash (aref bytes 43) 24))))
    (is (= data-chunk-size (* 2 (length samples))))
    (is (= (length bytes) (+ 44 (* 2 (length samples)))))))
