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
          :asdf-system "edm-engine/core")))
;; This whole generator is superseded by dps-meta scaffolding (lisp-actor
;; type) — kept only so ci.yml isn't hand-edited directly if regenerated
;; before the dps-meta migration lands. linter job dropped: 40ants-ci/jobs/linter
;; generates `qlot exec ros install 40ants-asdf-system 40ants-linter`, but
;; `40ants-linter` isn't a valid roswell-installable target (mismatches
;; the project's own README, which documents `cxxxr/sblint`). Upstream
;; bug in 40ants-ci itself, not edm-engine.
