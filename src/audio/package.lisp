(defpackage :edm-engine/audio
  (:use :cl)
  (:export
   #:generate-samples #:wav-bytes-for-samples
   #:play-tone #:ensure-audio-device #:*audio-device-ready*
   #:note-frequency #:mix-samples #:render-pattern #:play-pattern #:pattern-sound
   #:render-pattern-async #:theme-playback-decision #:ensure-theme-sound-async
   #:*pattern-cache* #:*pattern-pending*))
(in-package :edm-engine/audio)

