(defpackage :edm-engine
  (:use :cl)
  (:import-from :serapeum :~> :~>> :defconstructor :op)
  (:import-from :alexandria :curry :when-let :ensure-gethash :define-constant)
  (:export
   ;; handle
   #:handle #:handle-index #:handle-generation #:make-handle #:handle=
   ;; bus
   #:bus #:make-bus #:bus-topic #:bus-push #:bus-pop #:bus-try-pop #:*engine-bus*
   ;; arena
   #:arena #:make-arena #:arena-spawn #:arena-despawn #:arena-alive-p
   #:arena-position #:arena-set-position #:arena-velocity #:arena-set-velocity
   #:arena-live-handles
   ;; ruleset
   #:ruleset-load #:ruleset-unload
   ;; game protocol
   #:game-title #:game-update #:game-render #:game-outcome #:game-score #:game-save-data
   #:game-stop-audio
   #:game-entry #:game-entry-title #:game-entry-constructor #:game-entry-restore-fn
   #:game-entry-ai-capable-p
   #:*games* #:register-game
   ;; tick
   #:tick #:make-tick #:tick-frame #:advance-tick #:ensure-kernel
   ;; save/load — 10 slots, each with metadata + a screenshot
   #:*save-slot-count* #:*save-directory*
   #:save-slot-data-path #:save-slot-screenshot-path #:ensure-save-directory
   #:save-game-to-slot #:load-game-from-slot #:delete-save-slot
   #:list-save-slots #:format-save-timestamp #:log-crash #:*crash-log-path*
   ;; palette (chrome tokens + Okabe-Ito for functional state color)
   #:+color-dim+ #:+color-panel+ #:+color-brand-green+ #:+color-brand-green2+
   #:+color-amber+ #:+color-red+
   #:+okabe-ito-orange+ #:+okabe-ito-bluish-green+ #:+okabe-ito-sky-blue+
   #:rgb-scaled
   ;; monochromatic HSV theme system (chrome only — see palette.lisp)
   #:hsv->rgb #:rgb->hsv #:+theme-hue+ #:theme-color #:theme-hsv
   #:+theme-directions+ #:*theme-direction*
   #:+render-modes+ #:*render-mode* #:toggle-render-mode
   #:lerp #:ease-out-cubic #:tween #:make-tween #:tween-position #:tween-finished-p
   #:tween-start-x #:tween-start-y #:tween-end-x #:tween-end-y #:tween-start-time #:tween-duration
   #:centered-row-positions #:wrap-text-lines #:centered-grid-positions #:center-within
   #:+die-sides+ #:roll-die #:roll-dice-n #:roll-percentile
   #:roll-animation #:make-roll-animation #:roll-animation-finished-p #:roll-animation-display-values
   #:roll-animation-start-time #:roll-animation-duration #:roll-animation-final-values
   #:title-theme-pattern #:+title-theme-row-duration+
   ;; render (defined in edm-engine/render; declared here so main can call them)
   #:open-window #:close-window #:window-should-close-p #:draw-arena
   #:draw-chrome-rect #:ensure-chrome-shader #:set-shader-int #:set-shader-float
   #:draw-glyph-text #:glyph-text-width #:ensure-glyph-font #:draw-wrapped-text
   #:draw-ui-text #:ui-text-width #:ensure-ui-font #:ensure-mono-font
   #:+space-1+ #:+space-2+ #:+space-3+ #:+space-4+ #:+space-5+ #:+space-6+ #:+space-7+ #:+space-8+
   #:+radius-sm+ #:+radius-md+ #:+radius-lg+
   ;; arcade state machine (pure; the raylib update/render loop lives in
   ;; the primary edm-engine system's main.lisp, not here)
   #:+engine-name+ #:+main-menu-items+
   #:arcade-state #:make-arcade-state
   #:arcade-state-mode #:arcade-state-main-menu-index #:arcade-state-table-index
   #:arcade-state-current-game #:arcade-state-current-table-title #:arcade-state-ruleset-handle
   #:arcade-state-total-score #:arcade-state-volume #:arcade-state-options-cursor
   #:arcade-state-popup-open #:arcade-state-popup-index #:arcade-state-save-slot-index
   #:arcade-state-difficulty-index #:arcade-state-pending-entry
   #:arcade-select-next-difficulty #:arcade-select-previous-difficulty #:arcade-confirm-difficulty
   #:arcade-complete-launch
   #:cycle-index
   #:arcade-select-next-main-menu #:arcade-select-previous-main-menu
   #:arcade-dismiss-title
   #:arcade-drill-into-main-menu-selection #:arcade-back-to-main-menu
   #:clamp-volume #:arcade-increase-volume #:arcade-decrease-volume
   #:arcade-toggle-theme-direction #:arcade-select-next-option-row #:arcade-select-previous-option-row
   #:arcade-select-next-table #:arcade-select-previous-table
   #:arcade-launch-selected #:arcade-restart-current #:arcade-return-to-table-select
   #:arcade-popup-items #:arcade-open-popup #:arcade-popup-next #:arcade-popup-previous
   #:arcade-popup-confirm #:arcade-bank-score #:arcade-save-current
   #:arcade-select-next-save-slot #:arcade-select-previous-save-slot
   #:arcade-load-selected-save-slot
   ;; arcade entry point (defined in the primary edm-engine system)
   #:main #:arcade-update #:arcade-render #:rgb-color #:rgb-float->hex
   ;; AI opponent library — pacing timer + difficulty tiers, shared
   ;; across any AI-capable table
   #:ai-timer #:make-ai-timer #:ai-ready-p #:ai-timer-reset
   #:+ai-difficulty-tiers+ #:ai-difficulty-label #:*ai-difficulty*
   #:+ai-difficulty-glyphs+ #:+ai-difficulty-descriptions+))

(in-package :edm-engine)

