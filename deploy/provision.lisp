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

(defpackage :org.cimatrix.env.development
  (:use :cl :consfigurator)
  (:local-nicknames (#:apt #:consfigurator.property.apt)
                     (#:git #:consfigurator.property.git)
                     (#:cmd #:consfigurator.property.cmd)
                     (#:os #:consfigurator.property.os))
  (:export #:provision))

(in-package :org.cimatrix.env.development)


(defparameter *opa-version* "v0.11.0"
  "The open policy agent version for installation")
(defparameter *opa-uri" "https://github.com/open-policy-agent/opa/releases/download")

(defparameter *roswell-version* "23.10.14.114"
  "The roswell release to install. Update this, not the shell command
in PROVISION, when a newer roswell release is needed.")

(defparameter *roswell-uri* "https://github.com/roswell/roswell/releases/download"
  "BaseURI for the latest roswell package")

(defparameter *dev-dependencies* '("build-essential" "cmake" "git" "xvfb" "ffmpeg"
                   "libasound2-dev" "libx11-dev" "libxrandr-dev" "libxi-dev"
                   "libgl1-mesa-dev" "libglu1-mesa-dev" "libxcursor-dev"
                   "libxinerama-dev" "libwayland-dev" "libxkbcommon-dev"))


;; FIXME: consfigurator already has this function and one just calls the consfigurator version
;;        
;;        Where org.cimatrix.env.development is this package (using cispec/cimatrix abstractions)
;;        and where one in that package uses (defhost org.cimatrix.env.development ()...)
;;        and where one uses `(asdf:load-system :org.cimatrix.env.development) (deploy :sudo org.cimatrix.env.development)`

(defun provision (&key (suite :noble) (arch :amd64))
  "Provisions a bare machine to the point where raylib and the
roswell/sbcl/qlot toolchain exist — everything after this (qlot
install, ros make-edm-engine.ros) is unchanged, existing tooling.
SUITE/ARCH default to Ubuntu 24.04 (noble)/amd64, matching the CI
runner and this sandbox — override for a different target.

    ;; APT:INSTALLED's internal dispatch needs a concrete OS.DEBIAN
    ;; instance (not the abstract OS.DEBIANLIKE base class), with an
    ;; explicit suite and architecture — discovered by actually running
    ;; this against a real, missing-sudo sandbox, not assumed from docs.

    ;; 1. Build tools + policy gates + raylib's own dependencies, sourced from the
    ;; raylib wiki's own documented Ubuntu/Debian dependency line.

    ;; 2. raylib itself — clone and build from source, matching the exact
    ;; sequence already verified working manually earlier this session.
    ;; Pinned to the 6.0 stable release tag, not master — a real,
    ;; confirmed failure otherwise: master briefly had a genuine source
    ;; bug (IsPathAbsolute redeclared static in rcore.c after already
    ;; being declared non-static in raylib.h), caught by a real CI run
    ;; on a fresh runner even though this session's own sandbox had an
    ;; older, unaffected clone cached from earlier testing — the whole
    ;; reason to pin an upstream dependency, not track its unstable tip.
  
    ;; 3. Roswell -> SBCL -> qlot, reusing dps-meta's own proven working
    ;; sequence (verified in #16/#27's investigation) rather than
    ;; inventing a new one.
"
  (localsudon
    
    (has-hostattrs :os (make-instance 'os:debian :suite suite :arch arch))

    (apply #'apt:installed *dev-dependencies*)
    (cmd:single (format nil "curl -L -o /usr/local/bin/opa ~A/~A/opa_linux_amd64"
                       *opa-uri*
                       *opa-version*))
    (file:has-mode "/usr/local/bin/opa" #o644)
    
    (git:cloned "https://github.com/raysan5/raylib.git" #P"/opt/raylib/" "6.0")
    (dolist (cmake '(("cmake" "-S" "/opt/raylib" "-B" "/opt/raylib/build" 
                         "-DBUILD_SHARED_LIBS=ON" 
                         "-DCMAKE_BUILD_TYPE=Release" 
                         "-DBUILD_EXAMPLES=OFF" 
                         "-DBUILD_GAMES=OFF")
                ("cmake" "--build" "/opt/raylib/build" "-j$(nproc)")
                ("sh" "-c" "cmake --install /opt/raylib/build && ldconfig")))
                (apply #'cmd:single cmake))

    (dolist (ros '(("sh" "-c" (format nil 
                                  "curl -sL ~A/v~A/roswell_~A-1_amd64.deb -o /tmp/roswell.deb && dpkg -i /tmp/roswell.deb"
                        *roswell-uri* *roswell-version* *roswell-version*))
                    ("ros" "install" "sbcl-bin")
                    ("ros" "install" "qlot")))
                    (apply #'cmd:single ros))