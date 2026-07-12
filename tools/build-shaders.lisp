;;;; tools/build-shaders.lisp
;;;;
;;;; Compiles every src/games/*/shaders/*.{vs,fs}.lisp (c-mera GLSL S-expression
;;;; source) into the matching .vs/.fs GLSL text file raylib loads at runtime.
;;;;
;;;; c-mera's own CLI (roswell/cm.ros) parses argv via net.didierverna.clon,
;;;; which expects a real process argv and does not work when the processor
;;;; function is called directly with a manually-built argument list — it
;;;; always reports "No input specified." This script instead drives c-mera's
;;;; underlying read/traverse/pretty-print pipeline directly (the same steps
;;;; DEFINE-PROCESSOR performs internally), bypassing the CLI layer entirely.
;;;;
;;;; Usage: sbcl --non-interactive --load tools/build-shaders.lisp

;;;; Requires: quicklisp already loaded, and c-mera cloned into a quicklisp
;;;; local-projects directory, e.g.
;;;;   git clone https://github.com/kiselgra/c-mera.git \
;;;;     ~/quicklisp/local-projects/c-mera
;;;; (c-mera isn't distributed via Quicklisp or Ultralisp.)
;;;;
;;;; Usage: sbcl --non-interactive --load ~/quicklisp/setup.lisp \
;;;;   --load tools/build-shaders.lisp

(ql:register-local-projects)
(ql:quickload (list :c-mera :cm-c :cmu-c :cm-glsl :cmu-glsl :cms-glsl) :silent t)

(defun compile-glsl-file (source-path output-path)
  (let ((tree (cm-glsl::read-in-file (namestring source-path)))
        (pp (make-instance 'c-mera::pretty-printer)))
    (c-mera::traverser (make-instance 'cm-c::nested-nodelist-remover) tree 0)
    (c-mera::traverser (make-instance 'cm-c::else-if-traverser) tree 0)
    (c-mera::traverser (make-instance 'cm-c::if-blocker) tree 0)
    (c-mera::traverser (make-instance 'cm-c::decl-blocker) tree 0)
    (c-mera::traverser (make-instance 'cm-c::renamer) tree 0)
    (with-open-file (out output-path :direction :output
                                      :if-exists :supersede
                                      :if-does-not-exist :create)
      ;; c-mera's GLSL backend has no #version node — it's a preprocessor
      ;; pragma, not code, so it's this build script's job, not the DSL's.
      (format out "#version 330~%~%")
      (setf (slot-value pp 'c-mera::stream) out)
      (c-mera::traverser pp tree 0)
      (format out "~%"))
    (format t "~&[build-shaders] wrote ~A~%" output-path)))

(let ((*package* (find-package :cmu-glsl)))
  (setf (readtable-case *readtable*) :invert)
  (dolist (source (append
                    (directory (merge-pathnames "src/games/*/shaders/*.*.lisp" (uiop:getcwd)))
                    (directory (merge-pathnames "src/shaders/*.*.lisp" (uiop:getcwd)))))
    (let* ((namestring (namestring source))
           (output (parse-namestring (subseq namestring 0 (- (length namestring) 5))))) ; strip ".lisp"
      (compile-glsl-file source output))))
