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

;;; #22 — async theme generation via the bus + lparallel, restoring the
;;; originally-intended CSP architecture (#21) rather than blocking the
;;; main thread for the measured 44ms RENDER-PATTERN cost on first play.

(defvar *pattern-pending* (make-hash-table :test #'equal)
  "Keys currently being computed by a background task — presence here
means 'don't start a second task for this key', not that the samples
are ready yet.")

(defun ensure-theme-sound-async (pattern row-duration bus topic &key (amplitude 0.5))
  "Non-blocking replacement for PATTERN-SOUND's compute step — returns
the cached/ready raylib Sound, or NIL if generation is still in
flight (silence, not a blocking hitch, until it's ready — a better UX
than the old behavior, not just a performance fix). Safe to call every
frame; a cache hit or an already-pending key never starts a second
async task."
  (ensure-audio-device)
  (let* ((key (list pattern row-duration amplitude))
         (cache-hit-p (nth-value 1 (gethash key *pattern-cache*)))
         (pending-p (gethash key *pattern-pending*))
         samples ready-p)
    (when (and pending-p (not cache-hit-p))
      (multiple-value-setq (samples ready-p) (edm-engine:bus-try-pop bus topic)))
    (ecase (theme-playback-decision cache-hit-p pending-p ready-p)
      (:play-cached (gethash key *pattern-cache*))
      (:start-async
       (setf (gethash key *pattern-pending*) t)
       (render-pattern-async pattern row-duration bus topic :amplitude amplitude)
       nil)
      (:wrap-and-play
       (remhash key *pattern-pending*)
       (setf (gethash key *pattern-cache*) (samples->raylib-sound samples)))
      (:wait nil))))
