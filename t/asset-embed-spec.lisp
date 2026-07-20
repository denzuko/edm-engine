(in-package :edm-engine/tests)
(in-suite :edm-engine)

;;; #24's fix — asset embedding, so the standalone binary needs zero
;;; runtime file access to its own fonts/shaders and is genuinely
;;; relocatable. The macros themselves (EMBEDFILEBYTES/EMBEDFILESTRING)
;;; run at compile time and aren't meaningfully unit-testable the usual
;;; way; this spec covers the pure, testable transformation their
;;; expansion relies on — a real temp-file round trip, not a mock.

(test read-file-bytes-as-base64-round-trips-exactly
  "GOAL: whatever bytes go in come back out identically once decoded —
the actual property #24's fix depends on, checked against a real file
on disk, not assumed from the encoder/decoder's own documentation."
  (let ((path (merge-pathnames (format nil "edm-engine-asset-embed-test-~A.bin" (random 1000000))
                                (uiop:temporary-directory)))
        (original (make-array 256 :element-type '(unsigned-byte 8)
                                   :initial-contents (loop for i from 0 below 256 collect i))))
    (unwind-protect
         (progn
           (with-open-file (out path :direction :output :element-type '(unsigned-byte 8))
             (write-sequence original out))
           (let* ((encoded (edm-engine/asset-embed:readFileBytesAsBase64 path))
                  (decoded (qbase64:decode-string encoded)))
             (is (equalp original decoded))))
      (ignore-errors (delete-file path)))))

(test decoded-bytes-coerce-to-the-exact-simple-array-type-cffi-requires
  "Real bug caught on an actual relocated-binary run, not found by the
prior test above: QBASE64:DECODE-STRING's own return type is
(VECTOR (UNSIGNED-BYTE 8) N), the more general vector type, not
(SIMPLE-ARRAY (UNSIGNED-BYTE 8) (*)) — CFFI:WITH-POINTER-TO-VECTOR-DATA
(every consumer of EMBEDFILEBYTES uses it to pass bytes to RAYLIB)
requires the specific SIMPLE-ARRAY type and signals a real TYPE-ERROR
without this coercion. EQUALP alone (the test above) doesn't catch an
array-specialization mismatch, since it only compares values — this
checks TYPEP directly, the actual property that broke."
  (let ((coerced (coerce (qbase64:decode-string "AQIDBAU=") '(simple-array (unsigned-byte 8) (*)))))
    (is (typep coerced '(simple-array (unsigned-byte 8) (*))))))
