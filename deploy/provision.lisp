;;; deploy/provision.lisp — consfigurator property list for #15's precisely
;;; scoped job: build tools + raylib itself + the ros/sbcl/qlot toolchain,
;;; and only this. Lisp dependency resolution (qlot install) and building
;;; edm-engine itself (ros make-edm-engine.ros, per #4) are unchanged and
;;; NOT touched here — this stops the moment those three binaries and
;;; raylib exist on the machine.
;;;
;;; Bootstrap ordering, real and worth stating plainly: consfigurator
;;; itself needs libacl1-dev/libcap-dev to *load* at all (found live this
;;; session — CFFI-GROVEL failures without them). That's a real chicken-
;;; and-egg problem consfigurator can't solve for itself: those two
;;; packages must be installed with a direct `apt-get install`, by hand,
;;; before `qlot install` ever pulls consfigurator in. Not something this
;;; property list can express, since it can't run before it can load.
;;;
;;;   sudo apt-get install -y libacl1-dev libcap-dev   # consfigurator's
;;;                                                     # own prerequisite,
;;;                                                     # a one-time manual step
;;;   qlot install                                      # pulls consfigurator
;;;                                                      # (now that it can load)
;;;   qlot exec ros run --load deploy/provision.lisp \
;;;     --eval '(edm-engine-deploy:provision)' --eval '(uiop:quit 0)'

(ql:quickload :consfigurator :silent t)

(defpackage :edm-engine-deploy
  (:use :cl :consfigurator)
  (:local-nicknames (#:apt #:consfigurator.property.apt)
                     (#:git #:consfigurator.property.git)
                     (#:cmd #:consfigurator.property.cmd)
                     (#:os #:consfigurator.property.os))
  (:export #:provision))
(in-package :edm-engine-deploy)

(defparameter *roswell-version* "23.10.14.114"
  "The roswell release to install. Update this, not the shell command
in PROVISION, when a newer roswell release is needed.")

(defun provision (&key (suite :noble) (arch :amd64))
  "Provisions a bare machine to the point where raylib and the
roswell/sbcl/qlot toolchain exist — everything after this (qlot
install, ros make-edm-engine.ros) is unchanged, existing tooling.
SUITE/ARCH default to Ubuntu 24.04 (noble)/amd64, matching the CI
runner and this sandbox — override for a different target."
  (localsudon
    ;; APT:INSTALLED's internal dispatch needs a concrete OS.DEBIAN
    ;; instance (not the abstract OS.DEBIANLIKE base class), with an
    ;; explicit suite and architecture — discovered by actually running
    ;; this against a real, missing-sudo sandbox, not assumed from docs.
    (has-hostattrs :os (make-instance 'os:debian :suite suite :arch arch))

    ;; 1. Build tools + raylib's own dependencies, sourced from the
    ;; raylib wiki's own documented Ubuntu/Debian dependency line.
    (apt:installed "build-essential" "cmake" "git"
                   "libasound2-dev" "libx11-dev" "libxrandr-dev" "libxi-dev"
                   "libgl1-mesa-dev" "libglu1-mesa-dev" "libxcursor-dev"
                   "libxinerama-dev" "libwayland-dev" "libxkbcommon-dev")

    ;; 2. raylib itself — clone and build from source, matching the exact
    ;; sequence already verified working manually earlier this session.
    (git:cloned "https://github.com/raysan5/raylib.git" #P"/opt/raylib/")
    (cmd:single "sh" "-c"
                "cd /opt/raylib && mkdir -p build && cd build && cmake -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release .. && make && make install && ldconfig")

    ;; 3. Roswell -> SBCL -> qlot, reusing dps-meta's own proven working
    ;; sequence (verified in #16/#27's investigation) rather than
    ;; inventing a new one.
    (cmd:single "sh" "-c"
                (format nil "curl -sL https://github.com/roswell/roswell/releases/download/v~A/roswell_~A-1_amd64.deb -o /tmp/roswell.deb && dpkg -i /tmp/roswell.deb"
                        *roswell-version* *roswell-version*))
    (cmd:single "ros" "install" "sbcl-bin")
    (cmd:single "ros" "install" "qlot")))
