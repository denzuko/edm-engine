(defsystem "edm-engine/core"
  :description "Pure engine logic: handle, bus, arena, ruleset, tick. No I/O."
  :author "Dwight Spencer <denzuko@dapla.net>"
  :license "MIT"
  :version "0.1.0"
  :depends-on ("alexandria" "serapeum" "transducers" "chanl" "lparallel")
  :in-order-to ((test-op (test-op "edm-engine/tests")))
  :serial t
  :components ((:file "src/package")
               (:file "src/handle")
               (:file "src/bus")
               (:file "src/arena")
               (:file "src/ruleset")
               (:file "src/game-protocol")
               (:file "src/ai-opponent")
               (:file "src/palette")
               (:file "src/tween")
               (:file "src/layout")
               (:file "src/save")
               (:file "src/arcade")
               (:file "src/tick")))

(defsystem "edm-engine/audio/tone"
  :description "Pure on-the-fly waveform sample generation and tracker-style
pattern sequencing. No raylib, no I/O — this is what the generative audio
DSL is for, not pre-recorded samples."
  :serial t
  :components ((:file "src/audio/package")
               (:file "src/audio/tone")
               (:file "src/audio/tracker")))

(defsystem "edm-engine/audio"
  :description "raylib playback boundary for generated tones. Untested I/O,
same convention as render.lisp."
  :depends-on ("edm-engine/audio/tone" "cl-raylib" "cffi")
  :components ((:file "src/audio/playback")))

(defsystem "edm-engine/audio/tests"
  :description "FiveAM spec suite for edm-engine/audio/tone."
  :depends-on ("edm-engine/audio/tone" "fiveam")
  :components ((:file "t/audio/tone-spec")
               (:file "t/audio/tracker-spec"))
  :perform (test-op (o c)
             (unless (uiop:symbol-call :fiveam :run! :edm-engine-audio)
               (error "edm-engine/audio FiveAM suite failed"))))

(defsystem "edm-engine/render"
  :description "cl-raylib I/O boundary. Never unit-tested; kept thin by design."
  :depends-on ("edm-engine/core" "cl-raylib" "3d-vectors")
  :serial t
  :components ((:file "src/render")))

(defsystem "edm-engine/cards"
  :description "Deck/card primitives shared across any card game — extracted
from Hearts so a future card game (Solitaire, Blackjack, etc.) reuses this
instead of redefining it. Pure logic; no raylib."
  :depends-on ()
  :serial t
  :components ((:file "src/cards/package")
               (:file "src/cards/deck")))

(defsystem "edm-engine/cards/render"
  :description "Card-shape rendering shared across any card game — the
'panel + border + glyph' card silhouette any table with cards uses, not a
per-game reimplementation."
  :depends-on ("edm-engine/cards" "edm-engine/render")
  :components ((:file "src/cards/render")))

(defsystem "edm-engine"
  :description "EDM Arcade: tabletop/arcade game simulator binary. dps-meta lisp-actor artifact."
  :author "Dwight Spencer <denzuko@dapla.net>"
  :license "MIT"
  :version "0.1.0"
  :depends-on ("edm-engine/core" "edm-engine/render"
               "edm-engine/games/wordle" "edm-engine/games/wordle/render"
               "edm-engine/games/queens" "edm-engine/games/queens/render"
               "edm-engine/games/hearts" "edm-engine/games/hearts/render"
               "swank")
  :build-operation "program-op"
  :build-pathname "edm-engine"
  :entry-point "edm-engine:main"
  :components ((:file "src/main")))

(defsystem "edm-engine/docs"
  :description "40ants-doc documentation page."
  :depends-on ("edm-engine/core" "40ants-doc")
  :components ((:file "docs/index")))

(defsystem "edm-engine/ci"
  :description "40ants-ci workflow generator — reuses dps-meta's own job
classes (dps.meta.ci.jobs), not hand-rolled steps."
  :depends-on ("edm-engine/core" "40ants-ci" "dps-meta")
  :components ((:file "ci/package")))

(defsystem "edm-engine/games/wordle"
  :description "Wordle: transducers:filter over a corpus. No screamer — see
edm-engine/ruleset docstring for when constraint engines are warranted."
  :depends-on ("edm-engine/core" "transducers")
  :serial t
  :components ((:file "src/games/wordle/package")
               (:file "src/games/wordle/corpus")
               (:file "src/games/wordle/guess")
               (:file "src/games/wordle/game")
               (:file "src/games/wordle/music")))

(defsystem "edm-engine/games/wordle/render"
  :description "Wordle tile-grid renderer. Screen-centered; tile color is
a GLSL fragment-shader function of state, never a Lisp-side branch."
  :depends-on ("edm-engine/games/wordle" "edm-engine/render" "edm-engine/audio" "cffi")
  :components ((:file "src/games/wordle/render")))

(defsystem "edm-engine/games/queens"
  :description "Queens: one queen per row/column/region, no two adjacent
(incl. diagonally). Board+region generation via SCREAMER (A-MEMBER-OF +
ASSERT!) — the genuine first use of a constraint engine in this codebase;
Wordle never needed one."
  :depends-on ("edm-engine/core" "screamer")
  :serial t
  :components ((:file "src/games/queens/package")
               (:file "src/games/queens/board")
               (:file "src/games/queens/game")
               (:file "src/games/queens/music")))

(defsystem "edm-engine/games/queens/render"
  :description "Queens board renderer. Region colors reuse the engine's
existing CPU-side HSV->RGB (src/palette.lisp) rather than a second GPU
shader copy of the same math."
  :depends-on ("edm-engine/games/queens" "edm-engine/render" "edm-engine/audio")
  :components ((:file "src/games/queens/render")))

(defsystem "edm-engine/games/queens/tests"
  :description "FiveAM spec suite over edm-engine/games/queens."
  :depends-on ("edm-engine/games/queens" "fiveam")
  :serial t
  :components ((:file "t/games/queens/package")
               (:file "t/games/queens/board-spec")
               (:file "t/games/queens/game-spec")
               (:file "t/games/queens/music-spec")))

(defsystem "edm-engine/games/wordle/tests"
  :description "FiveAM spec suite for edm-engine/games/wordle."
  :depends-on ("edm-engine/games/wordle" "fiveam")
  :serial t
  :components ((:file "t/games/package")
               (:file "t/games/wordle-spec")
               (:file "t/games/wordle-game-spec")
               (:file "t/games/wordle-input-spec")
               (:file "t/games/wordle-music-spec"))
  :perform (test-op (o c)
             (unless (uiop:symbol-call :fiveam :run! :edm-engine-wordle)
               (error "edm-engine/games/wordle FiveAM suite failed"))))

(defsystem "edm-engine/tests/all"
  :description "Aggregates all four pure-logic FiveAM suites (core, wordle,
audio, queens) into one ASDF test-op — none of them depend on raylib, so
this is what CI actually runs, not just edm-engine/core."
  :depends-on ("edm-engine/tests" "edm-engine/games/wordle/tests" "edm-engine/audio/tests"
               "edm-engine/games/queens/tests" "edm-engine/games/hearts/tests")
  :perform (test-op (o c)
             (let ((results (list (uiop:symbol-call :fiveam :run! :edm-engine)
                                   (uiop:symbol-call :fiveam :run! :edm-engine-wordle)
                                   (uiop:symbol-call :fiveam :run! :edm-engine-audio)
                                   (uiop:symbol-call :fiveam :run! :edm-engine-queens)
                                   (uiop:symbol-call :fiveam :run! :edm-engine-hearts))))
               (unless (every #'identity results)
                 (error "one or more edm-engine FiveAM suites failed")))))

(defsystem "edm-engine/e2e"
  :description "Real end-to-end tests: drives the actual arcade (on a
thread, same process) via CLX + the XTEST X11 extension — genuine
synthesized input, not a shortcut through the pure state-transition
functions FiveAM already covers. Requires a running X server (Xvfb is
fine) with the XTEST extension available; not run by the default test
suite since it needs that plus a full raylib build."
  :depends-on ("edm-engine" "clx" "bordeaux-threads" "fiveam")
  :components ((:file "t/e2e/support")
               (:file "t/e2e/menu-e2e")))

(defsystem "edm-engine/tests"
  :description "FiveAM spec suite over edm-engine/core. Written before implementation, per BDD gate."
  :depends-on ("edm-engine/core" "fiveam")
  :serial t
  :components ((:file "t/package")
               (:file "t/handle-spec")
               (:file "t/bus-spec")
               (:file "t/arena-spec")
               (:file "t/ruleset-spec")
               (:file "t/game-registry-spec")
               (:file "t/arcade-menu-spec")
               (:file "t/theme-spec")
               (:file "t/tween-spec")
               (:file "t/layout-spec")
               (:file "t/ai-opponent-spec")
               (:file "t/tick-spec"))
  :perform (test-op (o c)
             (unless (uiop:symbol-call :fiveam :run! :edm-engine)
               (error "edm-engine FiveAM suite failed"))))

(defsystem "edm-engine/games/hearts"
  :description "Hearts: trick-taking, single human vs 3 AI opponents."
  :depends-on ("edm-engine/core" "edm-engine/cards")
  :serial t
  :components ((:file "src/games/hearts/package")
               (:file "src/games/hearts/rules")
               (:file "src/games/hearts/game")
               (:file "src/games/hearts/music")))

(defsystem "edm-engine/games/hearts/render"
  :description "Hearts table renderer."
  :depends-on ("edm-engine/games/hearts" "edm-engine/render" "edm-engine/audio" "edm-engine/cards/render")
  :components ((:file "src/games/hearts/render")))

(defsystem "edm-engine/games/hearts/tests"
  :description "FiveAM spec suite over edm-engine/games/hearts."
  :depends-on ("edm-engine/games/hearts" "edm-engine/cards" "fiveam")
  :serial t
  :components ((:file "t/games/hearts/package")
               (:file "t/games/hearts/rules-spec")
               (:file "t/games/hearts/game-spec")
               (:file "t/games/hearts/ui-helpers-spec")))
