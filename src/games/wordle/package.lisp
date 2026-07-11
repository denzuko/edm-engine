(defpackage :edm-engine/games/wordle
  (:use :cl)
  (:export
   #:evaluate-guess #:filter-candidates #:*corpus*
   #:draw-grid #:draw-tile #:grid-origin
   #:wordle-game #:make-wordle-game #:submit-guess #:rows-for-render
   #:wordle-game-answer #:wordle-game-history #:wordle-game-max-rows
   #:wordle-game-status #:wordle-game-input #:wordle-game-pulse
   #:push-letter #:pop-letter #:try-submit #:tick-pulse #:+pulse-max+))
(in-package :edm-engine/games/wordle)

(declaim (optimize (speed 3) (safety 3)))
