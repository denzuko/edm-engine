(defpackage #:edm-engine/ci
  (:use #:cl)
  (:import-from #:40ants-ci/workflow #:defworkflow)
  (:import-from #:dps.meta.ci.jobs #:opa-gate-job #:build-job #:sbom-job))
(in-package #:edm-engine/ci)

;; Reuses dps-meta's own reusable 40ants-ci job classes
;; (dps.meta.ci.jobs, github.com/denzuko/dps-meta, dps/meta/ci/jobs.lisp)
;; instead of either the built-in (and currently broken — see prior
;; commits) 40ants-ci/jobs/run-tests, or a hand-rolled job.
;;
;; BUILD-JOB is generic — :build-command/:artifact-name are constructor
;; args, not hardcoded to dps-meta's own asdf:make-based lisp-actor
;; build. Reused here with edm-engine's own build command: the same
;; roswell-via-pinned-.deb + qlot install dps-meta/mlisp both use
;; (ROS_VER=26.02.116), running the FiveAM suite via qlot exec instead
;; of asdf:make — edm-engine's CI goal is verifying the (raylib-free)
;; test suite, not building the raylib-dependent arcade binary, which
;; needs a native build environment CI doesn't have.
;;
;; OPA-GATE-JOB is reused as-is against edm-engine's own policy/gate.rego.
;; SBOM-JOB is reused as-is (generic cdxgen type — edm-engine isn't C).
;;
;; SLSA provenance/verify/release are NOT included: those key off
;; BUILD-JOB producing a real downloadable artifact, gated to tag
;; pushes. edm-engine doesn't cut tagged binary releases yet.

(defparameter +test-command+
  "ROS_VER=26.02.116
curl -sL \"https://github.com/roswell/roswell/releases/download/v${ROS_VER}/roswell_${ROS_VER}-1_amd64.deb\" -o /tmp/roswell.deb
sudo dpkg -i /tmp/roswell.deb
ros install qlot
qlot install
qlot exec ros run \\
  --eval \"(push (truename \\\".\\\") asdf:*central-registry*)\" \\
  --eval \"(asdf:test-system :edm-engine/tests/all)\" \\
  --eval \"(uiop:quit 0)\"")

(defworkflow ci
  :on-push-to "main"
  :on-pull-request t
  :jobs ((make-instance 'opa-gate-job)
         (make-instance 'build-job
                        :build-command +test-command+
                        :artifact-name "edm-engine")
         (make-instance 'sbom-job :cdxgen-type "generic")))
