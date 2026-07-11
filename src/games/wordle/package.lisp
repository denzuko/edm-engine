(defpackage :edm-engine/games/wordle
  (:use :cl)
  (:export
   #:evaluate-guess #:filter-candidates #:*corpus*))
(in-package :edm-engine/games/wordle)

(declaim (optimize (speed 3) (safety 3)))
