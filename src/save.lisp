(in-package :edm-engine)


(defparameter *save-slot-count* 10)

(defparameter *save-directory*
  (merge-pathnames ".parencade-saves/" (user-homedir-pathname))
  "Sexp over ASN.1: no extra dependency, trivially human-inspectable,
and the project is Lisp-native end to end — reading a save file with
PRIN1/READ costs nothing an ASN.1 codec wouldn't also need to pay for
in a much heavier form. Each slot is its own file rather than one
growing file so browsing/deleting a slot never touches the others.")

(declaim (ftype (function ((integer 0 9)) pathname) save-slot-data-path))
(defun save-slot-data-path (slot)
  (merge-pathnames (format nil "slot-~D.sexp" slot) *save-directory*))

(declaim (ftype (function ((integer 0 9)) pathname) save-slot-screenshot-path))
(defun save-slot-screenshot-path (slot)
  "PNG path for SLOT's thumbnail. This function only computes the path —
taking the actual screenshot is raylib I/O, done by the caller
(main.lisp) at the right point in the render loop, not here."
  (merge-pathnames (format nil "slot-~D.png" slot) *save-directory*))

(defun ensure-save-directory ()
  (ensure-directories-exist *save-directory*))

(declaim (ftype (function (t) fixnum) save-data-checksum))
(defun save-data-checksum (data)
  "SXHASH, not a cryptographic HMAC: the real threat model here is
accidental corruption (a partial write, a disk error, a hand-edited
file with a typo), not a malicious actor with write access to the
save file — anyone with that access could forge any checksum this
code computed anyway, so a full crypto dependency buys nothing real
for this specific, local, single-player use case."
  (sxhash data))

(declaim (ftype (function ((integer 0 9) string t fixnum) (integer 0 9)) save-game-to-slot))
(defun save-game-to-slot (slot table-title game score)
  "Writes SLOT's data: table title, score, a save timestamp,
GAME-SAVE-DATA, and a checksum of that data (verified on load — #9's
own integrity-checking gap). Returns SLOT."
  (ensure-save-directory)
  (let ((data (game-save-data game)))
    (with-open-file (out (save-slot-data-path slot) :direction :output
                                                      :if-exists :supersede :if-does-not-exist :create)
      (prin1 (list :table-title table-title :score score
                   :timestamp (get-universal-time)
                   :data data
                   :checksum (save-data-checksum data))
             out)))
  slot)

(declaim (ftype (function ((integer 0 9)) t) load-game-from-slot))
(defun load-game-from-slot (slot)
  "Returns (values table-title score timestamp data), or NIL if SLOT is
empty, corrupted, OR fails its own checksum. A malformed/truncated
save file (a real failure mode — a partial write from a crash
mid-save, disk error, or an old-format save from before some field
existed) is treated the same as an empty slot, not a special error
case LIST-SAVE-SLOTS' own per-slot loop would need its own handling
for — one corrupted slot must not prevent the other, genuinely valid
slots from listing. A save whose :DATA doesn't match its own
:CHECKSUM (SAVE-DATA-CHECKSUM's own integrity check, #9's remaining
scope) is rejected the same way, not silently trusted — an old-format
save with no :CHECKSUM field at all (NIL from a missing plist key)
also fails this check, correctly treated as unloadable rather than
loaded with unverified data."
  (let ((path (save-slot-data-path slot)))
    (when (probe-file path)
      (handler-case
          (with-open-file (in path)
            (let ((saved (read in)))
              (if (eql (getf saved :checksum) (save-data-checksum (getf saved :data)))
                  (values (getf saved :table-title) (getf saved :score)
                          (getf saved :timestamp) (getf saved :data))
                  (progn (log-crash (format nil "load-game-from-slot ~D: checksum mismatch" slot))
                         nil))))
        (error (c)
          (log-crash (format nil "load-game-from-slot ~D: ~A" slot c))
          nil)))))

(defun delete-save-slot (slot)
  (let ((data-path (save-slot-data-path slot))
        (shot-path (save-slot-screenshot-path slot)))
    (when (probe-file data-path) (delete-file data-path))
    (when (probe-file shot-path) (delete-file shot-path)))
  slot)

(declaim (ftype (function () list) list-save-slots))
(defun list-save-slots ()
  "SAVE-SLOT-COUNT elements, each NIL (empty slot) or a plist
(:slot N :table-title ... :score ... :timestamp ...) — metadata only,
no screenshot bytes; the slot browser loads those as a texture
separately, only for the currently-highlighted slot."
  (loop for slot from 0 below *save-slot-count*
        collect (multiple-value-bind (title score timestamp) (load-game-from-slot slot)
                  (when title
                    (list :slot slot :table-title title :score score :timestamp timestamp)))))

(declaim (ftype (function (fixnum) string) format-save-timestamp))
(defun format-save-timestamp (universal-time)
  (multiple-value-bind (sec min hour date month year) (decode-universal-time universal-time)
    (declare (ignore sec))
    (format nil "~4,'0D-~2,'0D-~2,'0D ~2,'0D:~2,'0D" year month date hour min)))

;;; Crash logging for #23's error boundary. Pure file I/O, no raylib
;;; dependency — belongs here (tested, pure) rather than main.lisp
;;; (untested-by-design render/entry-point layer), matching the same
;;; discipline that already keeps this file's save/load logic separate
;;; from arcade.lisp's UI-driving code.

(defparameter *crash-log-path*
  (merge-pathnames ".parencade-saves/crash.log" (user-homedir-pathname))
  "Sibling to *SAVE-DIRECTORY*, not inside it — a crash log is
diagnostic data, not game state.")

(defun log-crash (condition)
  "Best-effort — a failure to write the crash log itself should never
become a second, more confusing failure on top of the one it's
logging."
  (ignore-errors
    (ensure-directories-exist *crash-log-path*)
    (with-open-file (out *crash-log-path* :direction :output
                                           :if-exists :append
                                           :if-does-not-exist :create)
      (format out "~&[~A] ~A~%" (get-universal-time) condition))))
