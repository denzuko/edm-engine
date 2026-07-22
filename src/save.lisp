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

(defmacro defsave-data (struct-name &rest fields)
  "Defines a GAME-SAVE-DATA method for STRUCT-NAME, composing a plist
of :FIELD (STRUCT-NAME-FIELD game) pairs — #58's own finding: this
half of the save/load boilerplate is genuinely, mechanically identical
across all four games (checked directly, not assumed), only the field
list differs. The paired RESTORE-*-GAME function stays hand-written
per game — a real structural difference (Queens regenerates its board
then restores progress on top; the other three construct directly from
every field), not one this macro forces into a single shape."
  (let ((game-var (gensym "GAME")))
    `(defmethod game-save-data ((,game-var ,struct-name))
       (list ,@(loop for field in fields
                     append (list field `(,(intern (format nil "~A-~A" struct-name
                                                             (string field)))
                                            ,game-var)))))))

(declaim (ftype (function ((integer 0 9) string t fixnum) (integer 0 9)) save-slot-data))
(defun save-slot-data (slot table-title data score)
  "Writes SLOT's data: table title, score, a save timestamp, DATA
(already-computed GAME-SAVE-DATA, not a game object), and a checksum
of DATA (verified on load — #9's own integrity-checking gap). Returns
SLOT.

The actual entry point for the :SAVE-GAME bus event's own consumer —
per direct correction, the real 'Save State' UI flow was calling
SAVE-GAME-TO-SLOT (which computes GAME-SAVE-DATA itself) and
RAYLIB:TAKE-SCREENSHOT directly and synchronously in the same key-
handler, the exact direct-call pattern #37's own bus-driven VFX
trigger was built to replace and never applied here. GAME-SAVE-DATA
needs computing at push time (while the game object is still current,
before whatever handles the event runs later), so the event payload
carries DATA itself, not a game object the consumer would need to
call back into."
  (ensure-save-directory)
  (with-open-file (out (save-slot-data-path slot) :direction :output
                                                    :if-exists :supersede :if-does-not-exist :create)
    (prin1 (list :table-title table-title :score score
                 :timestamp (get-universal-time)
                 :data data
                 :checksum (save-data-checksum data))
           out))
  slot)

(declaim (ftype (function ((integer 0 9) string t fixnum) (integer 0 9)) save-game-to-slot))
(defun save-game-to-slot (slot table-title game score)
  "Convenience wrapper over SAVE-SLOT-DATA for any direct, synchronous
caller (ARCADE-SAVE-CURRENT, still used outside the :SAVE-GAME bus
event path) — computes GAME-SAVE-DATA from GAME, then composes
SAVE-SLOT-DATA rather than duplicating its own write logic."
  (save-slot-data slot table-title (game-save-data game) score))

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
