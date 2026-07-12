(defpackage :edm-engine/audio
  (:use :cl)
  (:export
   #:generate-samples #:wav-bytes-for-samples
   #:play-tone #:ensure-audio-device #:*audio-device-ready*))
(in-package :edm-engine/audio)

(declaim (optimize (speed 3) (safety 3)))
