(in-package :edm-engine/audio)

(declaim (optimize (speed 3) (safety 3)))

(declaim (ftype (function (integer) single-float) note-frequency))
(defun note-frequency (semitones-from-a4)
  "440Hz * 2^(n/12) — standard equal-temperament tuning, A4 = 0
semitones. Positive is up, negative is down; +12/-12 is one octave."
  (* 440.0 (expt 2.0 (/ semitones-from-a4 12.0))))

(declaim (ftype (function (list) (simple-array (signed-byte 16) (*))) mix-samples))
(defun mix-samples (sample-arrays)
  "Sums SAMPLE-ARRAYS (same length) sample-by-sample, clamped to
(SIGNED-BYTE 16) range — a real mix of simultaneous channels, not one
channel overwriting another."
  (let* ((n (length (first sample-arrays)))
         (result (make-array n :element-type '(signed-byte 16))))
    (dotimes (i n result)
      (let ((sum (reduce #'+ sample-arrays :key (lambda (a) (aref a i)))))
        (setf (aref result i) (max -32768 (min 32767 sum)))))))

(declaim (ftype (function (list single-float &key (:sample-rate fixnum) (:amplitude single-float))
                          (simple-array (signed-byte 16) (*)))
                render-pattern))
(defun render-pattern (pattern row-duration &key (sample-rate 44100) (amplitude 0.5))
  "PATTERN is a list of rows; each row is a list of per-channel entries,
each either NIL (silence) or (SEMITONES . WAVEFORM) — Protracker/MikMod
in spirit (note+instrument per row/channel), not literally MikMod.
Renders the whole pattern to one continuous PCM buffer using the same
GENERATE-SAMPLES engine UI SFX use, sequenced instead of played as
one-shot blips."
  (let ((row-buffers
          (mapcar
           (lambda (row)
             (let ((channel-buffers
                     (loop for entry in row
                           when entry
                             collect (generate-samples (cdr entry) (note-frequency (car entry))
                                                        row-duration :sample-rate sample-rate
                                                        :amplitude amplitude))))
               (if channel-buffers
                   (mix-samples channel-buffers)
                   (make-array (round (* row-duration sample-rate))
                               :element-type '(signed-byte 16) :initial-element 0))))
           pattern)))
    (apply #'concatenate '(simple-array (signed-byte 16) (*)) row-buffers)))
