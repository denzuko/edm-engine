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
               (:file "src/tick")))

(defsystem "edm-engine/render"
  :description "cl-raylib I/O boundary. Never unit-tested; kept thin by design."
  :depends-on ("edm-engine/core" "cl-raylib")
  :serial t
  :components ((:file "src/render")))

(defsystem "edm-engine"
  :description "EDM Arcade: tabletop/arcade game simulator binary. dps-meta lisp-actor artifact."
  :author "Dwight Spencer <denzuko@dapla.net>"
  :license "MIT"
  :version "0.1.0"
  :depends-on ("edm-engine/core" "edm-engine/render")
  :build-operation "program-op"
  :build-pathname "edm-engine"
  :entry-point "edm-engine:main"
  :components ((:file "src/main")))

(defsystem "edm-engine/docs"
  :description "40ants-doc documentation page."
  :depends-on ("edm-engine/core" "40ants-doc")
  :components ((:file "docs/index")))

(defsystem "edm-engine/ci"
  :description "40ants-ci workflow generator — superseded by dps-meta scaffolding.
Kept for reference; dps-meta owns .github/workflows/ci.yml generation now."
  :depends-on ("edm-engine/core" "40ants-ci")
  :components ((:file "ci/package")))

(defsystem "edm-engine/games/wordle"
  :description "Wordle: transducers:filter over a corpus. No screamer — see
edm-engine/ruleset docstring for when constraint engines are warranted."
  :depends-on ("edm-engine/core" "transducers")
  :serial t
  :components ((:file "src/games/wordle/package")
               (:file "src/games/wordle/corpus")
               (:file "src/games/wordle/guess")))

(defsystem "edm-engine/games/wordle/render"
  :description "Wordle tile-grid renderer. Screen-centered; tile color is
a GLSL fragment-shader function of state, never a Lisp-side branch."
  :depends-on ("edm-engine/games/wordle" "edm-engine/render" "cffi")
  :components ((:file "src/games/wordle/render")))

(defsystem "edm-engine/games/wordle/tests"
  :description "FiveAM spec suite for edm-engine/games/wordle."
  :depends-on ("edm-engine/games/wordle" "fiveam")
  :serial t
  :components ((:file "t/games/package")
               (:file "t/games/wordle-spec"))
  :perform (test-op (o c)
             (unless (uiop:symbol-call :fiveam :run! :edm-engine-wordle)
               (error "edm-engine/games/wordle FiveAM suite failed"))))

(defsystem "edm-engine/tests"
  :description "FiveAM spec suite over edm-engine/core. Written before implementation, per BDD gate."
  :depends-on ("edm-engine/core" "fiveam")
  :serial t
  :components ((:file "t/package")
               (:file "t/handle-spec")
               (:file "t/bus-spec")
               (:file "t/arena-spec")
               (:file "t/ruleset-spec")
               (:file "t/tick-spec"))
  :perform (test-op (o c)
             (unless (uiop:symbol-call :fiveam :run! :edm-engine)
               (error "edm-engine FiveAM suite failed"))))
