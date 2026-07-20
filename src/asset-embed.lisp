(defpackage :edm-engine/asset-embed
  (:use :cl)
  (:export #:embedFileBytes #:embedFileString #:readFileBytes #:readFileBytesAsBase64))
(in-package :edm-engine/asset-embed)

;;; #24's fix: every asset (fonts, shaders) currently resolves via
;;; ASDF:SYSTEM-RELATIVE-PATHNAME at *runtime*, requiring the source
;;; tree to still exist wherever the compiled binary is run from — the
;;; concrete failure mode is copying the binary anywhere else and
;;; having every font/shader load fail. These macros run at BUILD time
;;; instead (ASDF:SYSTEM-RELATIVE-PATHNAME still works fine then, since
;;; the source tree genuinely exists during the build), embedding the
;;; actual bytes into the resulting standalone executable's own heap
;;; image via SAVE-LISP-AND-DIE — zero runtime file access needed at
;;; all for these assets, the actual fix, not a workaround.

(defun readFileBytes (path)
  "Reads PATH as raw (UNSIGNED-BYTE 8) bytes. Build-time helper, called
from EMBEDFILEBYTES' own macro expansion — never present in, or called
from, the built binary at runtime."
  (with-open-file (in path :element-type '(unsigned-byte 8))
    (let ((buf (make-array (file-length in) :element-type '(unsigned-byte 8))))
      (read-sequence buf in)
      buf)))

(defun readFileBytesAsBase64 (path)
  "READFILEBYTES, base64-encoded — the pure, testable transformation
EMBEDFILEBYTES' macro expansion relies on (t/asset-embed-spec.lisp).
Base64, not a raw literal vector, purely for compiler efficiency: a
string literal is a single token the reader/compiler processes, not
hundreds of thousands of separate number tokens for a large font file
(DejaVuSans.ttf alone is ~760KB)."
  (qbase64:encode-bytes (readFileBytes path)))

(defmacro embedFileBytes (relative-path &key (system :edm-engine))
  "Expands, at compile time, to a form that reconstructs RELATIVE-PATH's
exact byte content at load time. RELATIVE-PATH is resolved via ASDF
against SYSTEM at macro-expansion (build) time only.

Coerces the decoded result to (SIMPLE-ARRAY (UNSIGNED-BYTE 8) (*))
explicitly — QBASE64:DECODE-STRING's own return type is the more
general (VECTOR (UNSIGNED-BYTE 8) N), confirmed directly, not assumed;
CFFI:WITH-POINTER-TO-VECTOR-DATA (used by every consumer of this
macro to pass the bytes to RAYLIB) requires the specific SIMPLE-ARRAY
type and signals a real TYPE-ERROR without this coercion — caught on
an actual isolated-directory run, not found in the sandbox's own
build/test cycle, which is exactly the class of thing this whole fix
exists to catch before a real player would hit it."
  (let ((encoded (readFileBytesAsBase64 (asdf:system-relative-pathname system relative-path))))
    `(coerce (qbase64:decode-string ,encoded) '(simple-array (unsigned-byte 8) (*)))))

(defmacro embedFileString (relative-path &key (system :edm-engine))
  "For text assets (shaders) — embeds the raw text directly as a
string literal at compile time, no base64 needed since it's already
textual, unlike the binary font case EMBEDFILEBYTES handles."
  (let ((path (asdf:system-relative-pathname system relative-path)))
    (with-open-file (in path)
      (let* ((buf (make-string (file-length in)))
             (n (read-sequence buf in)))
        (subseq buf 0 n)))))
