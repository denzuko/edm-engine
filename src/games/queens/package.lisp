(screamer:define-screamer-package :edm-engine/games/queens
  (:export
   #:+queens-level-count+ #:queens-board-size-for-level #:queens-seed-for-level
   #:queens-board #:queens-board-size #:queens-board-regions #:queens-board-placement #:region-at
   #:generate-board
   #:queens-game #:make-queens-game #:queens-game-level #:queens-game-score
   #:queens-game-board #:queens-game-placed #:queens-game-status
   #:queens-game-cursor-row #:queens-game-cursor-col #:move-cursor
   #:cell-state #:cycle-cell #:cycle-cell-at-cursor #:queens-conflicts
   #:queens-solved-p #:queens-game-points-for-level #:clamp-to-board
   #:queens-game-marked
   #:queens-theme-pattern #:+queens-theme-row-duration+))
