(defpackage :edm-engine/games/yahtzee
  (:use :cl)
  (:export
   #:roll-dice #:reroll-dice
   #:score-ones #:score-twos #:score-threes #:score-fours #:score-fives #:score-sixes
   #:score-three-of-a-kind #:score-four-of-a-kind #:score-full-house
   #:score-small-straight #:score-large-straight #:score-yahtzee #:score-chance
   #:score-category #:+categories+ #:upper-category-p
   #:upper-section-total #:upper-bonus-p #:+upper-bonus+ #:+upper-bonus-threshold+
   #:grand-total
   #:yahtzee-game #:make-yahtzee-game #:yahtzee-game-dice #:yahtzee-game-held
   #:yahtzee-game-rolls-remaining #:yahtzee-game-scores #:yahtzee-game-turn
   #:yahtzee-game-player-count #:yahtzee-game-cursor #:yahtzee-game-status
   #:toggle-hold #:roll-turn-dice #:commit-score #:available-categories
   #:ai-choose-holds #:ai-choose-category
   #:turn-over-p #:game-over-p #:winner-index #:advance-turn))
