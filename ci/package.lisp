(defpackage #:edm-engine/ci
  (:use #:cl)
  (:import-from #:40ants-ci/workflow #:defworkflow)
  (:import-from #:40ants-ci/jobs/job #:job)
  (:import-from #:40ants-ci/steps/action #:action)
  (:import-from #:40ants-ci/steps/sh #:sh))
(in-package #:edm-engine/ci)

;; 40ants-ci/jobs/run-tests + lisp-job hard-wire two GitHub Actions
;; (40ants/setup-lisp@v4, 40ants/run-tests@v2) into their STEPS method —
;; not overridable via keyword args, since that method APPENDs its own
;; fixed action step onto whatever the base class provides. As of
;; 2026-07-12 both actions are broken on ubuntu-latest runners: setup-lisp
;; references Windows paths (C:\Users\runneradmin\...) even when
;; runs-on is ubuntu-latest, and recovers into a broken HTTP-client
;; dependency chain (dexador/quri/babel-encodings) inside its own
;; bootstrapping, unrelated to edm-engine's code. Confirmed via GH Actions
;; run 29203793910 and several before it — CI was red across many
;; unrelated commits, the same failure regardless of what changed,
;; which is the signature of an upstream tooling bug, not a config
;; mistake here.
;;
;; Worked around with a genuinely custom JOB (base class only, not
;; RUN-TESTS/LISP-JOB) built from the SH/ACTION step primitives —
;; a plain Quicklisp bootstrap, the exact pattern already proven
;; reliable throughout this session's own sandbox work, every FiveAM
;; suite this project has is raylib-free, so this needs nothing beyond
;; stock Quicklisp.
(defparameter +bootstrap-and-test+
  "sudo apt-get update -qq
sudo apt-get install -y -qq sbcl
curl -sO https://beta.quicklisp.org/quicklisp.lisp
sbcl --non-interactive --load quicklisp.lisp \\
  --eval '(quicklisp-quickstart:install :path (merge-pathnames \"quicklisp/\" (user-homedir-pathname)))'
sbcl --non-interactive \\
  --load ~/quicklisp/setup.lisp \\
  --eval '(push (truename \".\") asdf:*central-registry*)' \\
  --eval '(ql:quickload :edm-engine/tests/all)' \\
  --eval '(asdf:test-system :edm-engine/tests/all)'")

(defworkflow ci
  :on-push-to "main"
  :on-pull-request t
  :jobs ((make-instance 'job
                         :name "run-tests"
                         :os "ubuntu-latest"
                         :steps (list (action "Checkout Code" "actions/checkout@v4")
                                      (sh "Bootstrap and Test" +bootstrap-and-test+)))))
