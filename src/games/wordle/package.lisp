(defpackage :edm-engine/games/wordle
  (:use :cl)
  (:export
   #:evaluate-guess #:filter-candidates #:*corpus*
   #:draw-grid #:draw-tile #:grid-origin
   #:wordle-game #:make-wordle-game #:submit-guess #:rows-for-render
   #:wordle-game-answer #:wordle-game-history #:wordle-game-max-rows
   #:wordle-game-status))
(in-package :edm-engine/games/wordle)

(declaim (optimize (speed 3) (safety 3)))
