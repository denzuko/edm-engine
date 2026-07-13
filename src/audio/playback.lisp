(in-package :edm-engine/audio)


(defvar *audio-device-ready* nil)
(defun ensure-audio-device ()
  (unless *audio-device-ready*
    (raylib:init-audio-device)
    (setf *audio-device-ready* t)))

(defun samples->raylib-sound (samples)
  "Wraps SAMPLES (mono 16-bit PCM, any source — a single tone or a whole
rendered tracker pattern) in a WAV header and loads it as a raylib
Sound. The one place PCM data crosses into raylib, shared by both
PLAY-TONE and PLAY-PATTERN."
  (let* ((bytes (wav-bytes-for-samples samples 44100))
         (n (length bytes)))
    (cffi:with-foreign-object (buf :unsigned-char n)
      (dotimes (i n) (setf (cffi:mem-aref buf :unsigned-char i) (aref bytes i)))
      (raylib:load-sound-from-wave (raylib:load-wave-from-memory ".wav" buf n)))))

(defun cached-or-compute (cache key compute-fn)
  "Looks up KEY in CACHE (an EQUAL hash-table); computes via COMPUTE-FN
and stores it if absent. The 'look up or compute+store' shape TONE-
SOUND and PATTERN-SOUND both had duplicated, differing only in which
cache table and what to compute."
  (or (gethash key cache)
      (setf (gethash key cache) (funcall compute-fn))))

(defvar *tone-cache* (make-hash-table :test #'equal)
  "Sounds are generated once per distinct (waveform freq duration amplitude)
and reused — regenerating PCM samples every frame would be wasteful, and
raylib Sound objects are native resources, not something to churn.")

(defun tone-sound (waveform frequency duration &key (amplitude 0.5))
  (ensure-audio-device)
  (cached-or-compute
   *tone-cache* (list waveform frequency duration amplitude)
   (lambda ()
     (samples->raylib-sound
      (generate-samples waveform (float frequency 1.0)
                         (float duration 1.0) :amplitude (float amplitude 1.0))))))

(defun play-tone (waveform frequency duration &key (amplitude 0.5))
  "Plays a WAVEFORM tone at FREQUENCY Hz for DURATION seconds — generated
on the fly, per the engine's generative-audio direction, never a
pre-recorded sample file."
  (raylib:play-sound (tone-sound waveform frequency duration :amplitude amplitude)))

(defvar *pattern-cache* (make-hash-table :test #'equal)
  "Same rationale as *TONE-CACHE* — a looping background pattern
shouldn't re-render its PCM data on every loop.")

(defun pattern-sound (pattern row-duration &key (amplitude 0.5))
  (ensure-audio-device)
  (cached-or-compute
   *pattern-cache* (list pattern row-duration amplitude)
   (lambda ()
     (samples->raylib-sound
      (render-pattern pattern (float row-duration 1.0) :amplitude (float amplitude 1.0))))))

(defun play-pattern (pattern row-duration &key (amplitude 0.5))
  "Plays a whole tracker PATTERN — the same GENERATE-SAMPLES/PLAY-TONE
machinery, sequenced. This is the music engine: no separate synth path,
no pre-recorded instrument samples, the exact same on-the-fly waveform
generation UI SFX use."
  (raylib:play-sound (pattern-sound pattern row-duration :amplitude amplitude)))
