(in-package :edm-engine/audio)

(declaim (optimize (speed 3) (safety 3)))

(defvar *audio-device-ready* nil)
(defun ensure-audio-device ()
  (unless *audio-device-ready*
    (raylib:init-audio-device)
    (setf *audio-device-ready* t)))

(defvar *tone-cache* (make-hash-table :test #'equal)
  "Sounds are generated once per distinct (waveform freq duration amplitude)
and reused — regenerating PCM samples every frame would be wasteful, and
raylib Sound objects are native resources, not something to churn.")

(defun tone-sound (waveform frequency duration &key (amplitude 0.5))
  (ensure-audio-device)
  (let ((key (list waveform frequency duration amplitude)))
    (or (gethash key *tone-cache*)
        (setf (gethash key *tone-cache*)
              (let* ((samples (generate-samples waveform (float frequency 1.0)
                                                 (float duration 1.0) :amplitude (float amplitude 1.0)))
                     (bytes (wav-bytes-for-samples samples 44100))
                     (n (length bytes)))
                (cffi:with-foreign-object (buf :unsigned-char n)
                  (dotimes (i n) (setf (cffi:mem-aref buf :unsigned-char i) (aref bytes i)))
                  (raylib:load-sound-from-wave (raylib:load-wave-from-memory ".wav" buf n))))))))

(defun play-tone (waveform frequency duration &key (amplitude 0.5))
  "Plays a WAVEFORM tone at FREQUENCY Hz for DURATION seconds — generated
on the fly, per the engine's generative-audio direction, never a
pre-recorded sample file."
  (raylib:play-sound (tone-sound waveform frequency duration :amplitude amplitude)))
