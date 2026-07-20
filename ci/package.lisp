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
  --eval '(ql-dist:install-dist \"http://dist.ultralisp.org/\" :prompt nil)' \\
  --eval '(ql:quickload :edm-engine/tests/all)' \\
  --eval '(asdf:test-system :edm-engine/tests/all)'")

;; #16's remaining scope: CI never built or verified the actual binary,
;; only pure-logic specs. This step provisions raylib (via #15's
;; consfigurator design, live-verified against a real missing-sudo
;; sandbox before landing here) and builds the real binary via
;; ros make-edm-engine.ros (#4's fix), giving CI something beyond
;; FiveAM specs to actually verify a commit against. Wiring the real
;; e2e suite (#35) in is separate, deliberate follow-on scope — that
;; suite currently crashes even on its simplest test and needs its own
;; fix before it belongs in a required CI step, not bundled in here
;; where a broken suite would just make every commit red for an
;; unrelated reason.
(defparameter +provision-and-build+
  "sudo apt-get install -y -qq libacl1-dev libcap-dev sudo
which ros || (curl -sL https://github.com/roswell/roswell/releases/download/v23.10.14.114/roswell_23.10.14.114-1_amd64.deb -o /tmp/roswell.deb && sudo dpkg -i /tmp/roswell.deb)
ros install sbcl-bin
ros install qlot
export PATH=\"$PATH:$HOME/.roswell/bin\"
qlot install
qlot exec ros run --load deploy/provision.lisp \\
  --eval '(edm-engine-deploy:provision)' \\
  --eval '(uiop:quit 0)'
qlot exec ros build make-edm-engine.ros")

;; #35's suite is fixed and passes reliably in this project's own dev
;; sandbox (12/12, confirmed across multiple runs). Wiring it in here
;; was attempted (+run-e2e-tests+ below, kept for the next attempt) and
;; genuinely failed on a real GitHub Actions runner with a DIFFERENT
;; error than anything seen in the sandbox: every test failed with
;; "TYPE-ERROR: -1 is not of type (UNSIGNED-BYTE 32)", not reproduced
;; locally despite trying (KEYSYM->KEYCODES returns a valid keycode in
;; this sandbox's Xvfb). Genuinely CI-runner-specific — worth its own
;; investigation with a proper backtrace captured, not a guess landed
;; without evidence. Reverted to keep CI green rather than merge a step
;; that's known-broken on the actual target environment. See #35's
;; follow-up issue.
(defparameter +run-e2e-tests+
  "export PATH=\"$PATH:$HOME/.roswell/bin\"
sudo apt-get install -y -qq xvfb
Xvfb :99 -screen 0 1280x1024x24 +extension XKEYBOARD &
sleep 2
export DISPLAY=:99
export LIBGL_ALWAYS_SOFTWARE=1
qlot exec ros run \\
  --eval '(ql:quickload :edm-engine/e2e :silent t)' \\
  --eval '(let ((r (fiveam:run (quote :edm-engine-e2e)))) (fiveam:explain! r) (unless (fiveam:results-status r) (uiop:quit 1)))' \\
  --eval '(uiop:quit 0)'")

;; Confirmed 40ants/setup-lisp@v4 genuinely works now (its own steps
;; correctly set shell: lispsh -eo pipefail internally, per its own
;; docs) — the earlier session's "both actions broken on ubuntu-latest"
;; diagnosis doesn't hold for this action specifically, checked
;; directly against a real CI run rather than left assumed.
;;
;; 40ants/run-tests@v2 itself hit a real, different, more specific
;; failure: "Component NIL not found" when driving EDM-ENGINE/TESTS/
;; ALL's own TEST-OP method through the action's internal wrapper
;; (RUN-TESTS.ROS) — not reproduced or explained further here. Worked
;; around with the action's own documented CUSTOM parameter, bypassing
;; its ASDF:TEST-SYSTEM invocation entirely and calling the exact same
;; FIVEAM:RUN! forms EDM-ENGINE/TESTS/ALL's own TEST-OP method already
;; runs (edm-engine.asd) — proven logic, not new.
(defparameter +standard-run-tests-custom+
  "(ql:quickload :edm-engine/tests/all)
(let ((results (list (fiveam:run! :edm-engine) (fiveam:run! :edm-engine-wordle)
                      (fiveam:run! :edm-engine-audio) (fiveam:run! :edm-engine-queens)
                      (fiveam:run! :edm-engine-hearts))))
  (unless (every #'identity results) (error \"one or more edm-engine FiveAM suites failed\")))")

(defworkflow ci
  :on-push-to "main"
  :on-pull-request t
  :jobs ((make-instance 'job
                         :name "run-tests"
                         :os "ubuntu-latest"
                         :steps (list (action "Checkout Code" "actions/checkout@v4")
                                      (sh "Bootstrap and Test" +bootstrap-and-test+)))
         (make-instance 'job
                         :name "build-binary"
                         :os "ubuntu-latest"
                         :steps (list (action "Checkout Code" "actions/checkout@v4")
                                      (sh "Provision and Build" +provision-and-build+)))
         (make-instance '40ants-ci/jobs/run-tests:run-tests
                         :name "standard-run-tests"
                         :asdf-system "edm-engine/tests/all"
                         :custom +standard-run-tests-custom+)))
