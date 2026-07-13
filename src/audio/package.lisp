(defpackage :edm-engine/audio
  (:use :cl)
  (:export
   #:generate-samples #:wav-bytes-for-samples
   #:play-tone #:ensure-audio-device #:*audio-device-ready*
   #:note-frequency #:mix-samples #:render-pattern #:play-pattern))
(in-package :edm-engine/audio)

