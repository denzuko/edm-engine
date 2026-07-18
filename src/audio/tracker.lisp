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

;;; #22's async theme-generation state machine — pure, no raylib/bus/
;;; lparallel dependency, belongs here (tested) rather than
;;; PLAYBACK.LISP (untested I/O boundary), same discipline that moved
;;; #23's LOG-CRASH into the tested core.

;;; #22's async theme-generation machinery — pure, no raylib dependency,
;;; belongs here (tested) rather than PLAYBACK.LISP (untested I/O
;;; boundary), same discipline that moved #23's LOG-CRASH into the
;;; tested core. Needs EDM-ENGINE/CORE for BUS-PUSH/ENSURE-KERNEL —
;;; still "no raylib, no I/O" per this system's own description; CHANL/
;;; LPARALLEL are in-process concurrency, not display/audio I/O.

(defun render-pattern-async (pattern row-duration bus topic &key (amplitude 0.5))
  "Non-blocking. Kicks off an LPARALLEL task computing RENDER-PATTERN
(the measured 44ms DSP cost, no raylib dependency) on a worker thread,
and BUS-PUSHes the finished sample array onto TOPIC when done. Never
touches raylib itself — that stays on whichever thread calls
ENSURE-THEME-SOUND-ASYNC (PLAYBACK.LISP), matching the verified split
between the two halves of the old synchronous PATTERN-SOUND."
  (edm-engine:ensure-kernel)
  (lparallel:future
    (edm-engine:bus-push bus topic
                          (render-pattern pattern (float row-duration 1.0)
                                           :amplitude (float amplitude 1.0)))))

(defun theme-playback-decision (cache-hit-p pending-p samples-ready-p)
  "The pure state machine driving ENSURE-THEME-SOUND-ASYNC
(PLAYBACK.LISP), factored out here so it has real FiveAM coverage
rather than being buried in bus/lparallel/raylib I/O. Given the three
boolean facts about a theme's current state, returns one of
:PLAY-CACHED / :START-ASYNC / :WRAP-AND-PLAY / :WAIT."
  (cond
    (cache-hit-p :play-cached)
    ((not pending-p) :start-async)
    (samples-ready-p :wrap-and-play)
    (t :wait)))
