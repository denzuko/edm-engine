(defsystem "edm-engine"
  :description "EDM game engine core: arena, bus, tick — pure logic, no I/O."
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
  :depends-on ("edm-engine" "cl-raylib")
  :serial t
  :components ((:file "src/render")))

(defsystem "edm-engine/docs"
  :description "40ants-doc documentation page."
  :depends-on ("edm-engine" "40ants-doc")
  :components ((:file "docs/index")))

(defsystem "edm-engine/ci"
  :description "40ants-ci workflow generator — no hand-written YAML."
  :depends-on ("edm-engine" "40ants-ci")
  :components ((:file "ci/package")))

(defsystem "edm-engine/tests"
  :description "FiveAM spec suite. Written before implementation, per BDD gate."
  :depends-on ("edm-engine" "fiveam")
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
