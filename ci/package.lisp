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
          :asdf-system "edm-engine/tests/all")))
;; This whole generator is superseded by dps-meta scaffolding (lisp-actor
;; type) — kept only so ci.yml isn't hand-edited directly if regenerated
;; before the dps-meta migration lands. linter job dropped: 40ants-ci/jobs/linter
;; generates `qlot exec ros install 40ants-asdf-system 40ants-linter`, but
;; `40ants-linter` isn't a valid roswell-installable target (mismatches
;; the project's own README, which documents `cxxxr/sblint`). Upstream
;; bug in 40ants-ci itself, not edm-engine.
;;
;; edm-engine/tests/all aggregates all three pure-logic FiveAM suites
;; (core/wordle/audio, 190 checks) — none of them depend on raylib by
;; design, so this is the real test surface without needing libraylib/
;; GLX built on the runner. edm-engine/e2e (real X11 input via CLX+XTEST)
;; is NOT run here — it needs a full raylib build + Xvfb + XTEST on the
;; runner, a real further step, not done yet.
