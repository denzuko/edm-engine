(defpackage :edm-engine
  (:use :cl)
  (:import-from :serapeum :~> :~>> :defconstructor :op)
  (:import-from :alexandria :curry :when-let :ensure-gethash :define-constant)
  (:export
   ;; handle
   #:handle #:handle-index #:handle-generation #:make-handle #:handle=
   ;; bus
   #:bus #:make-bus #:bus-topic #:bus-push #:bus-pop #:bus-try-pop
   ;; arena
   #:arena #:make-arena #:arena-spawn #:arena-despawn #:arena-alive-p
   #:arena-position #:arena-set-position #:arena-velocity #:arena-set-velocity
   #:arena-live-handles
   ;; ruleset
   #:ruleset-load #:ruleset-unload
   ;; game protocol
   #:game-title #:game-update #:game-render #:game-outcome
   #:game-entry #:game-entry-title #:game-entry-constructor #:*games* #:register-game
   ;; tick
   #:tick #:make-tick #:tick-frame #:advance-tick #:ensure-kernel
   ;; render (defined in edm-engine/render; declared here so main can call them)
   #:open-window #:close-window #:window-should-close-p #:draw-arena
   ;; arcade state machine (pure; the raylib update/render loop lives in
   ;; the primary edm-engine system's main.lisp, not here)
   #:+engine-name+ #:+main-menu-items+
   #:arcade-state #:make-arcade-state
   #:arcade-state-mode #:arcade-state-main-menu-index #:arcade-state-table-index
   #:arcade-state-current-game #:arcade-state-current-table-title #:arcade-state-ruleset-handle
   #:arcade-select-next-main-menu #:arcade-select-previous-main-menu
   #:arcade-drill-into-main-menu-selection #:arcade-back-to-main-menu
   #:arcade-select-next-table #:arcade-select-previous-table
   #:arcade-launch-selected #:arcade-restart-current #:arcade-return-to-table-select
   ;; arcade entry point (defined in the primary edm-engine system)
   #:main))

(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))
