(defpackage #:edm-engine/ci
  (:use #:cl)
  (:import-from #:40ants-ci/workflow #:defworkflow)
  (:import-from #:40ants-ci/jobs/run-tests)
  (:import-from #:40ants-ci/jobs/linter))
(in-package #:edm-engine/ci)

(defworkflow ci
  :on-push-to "main"
  :on-pull-request t
  :cache t
  :jobs ((40ants-ci/jobs/run-tests:run-tests
          :asdf-system "edm-engine")
         (40ants-ci/jobs/linter:linter
          :asdf-systems ("edm-engine"))))
