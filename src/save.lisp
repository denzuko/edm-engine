(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

(defparameter *default-save-path*
  (merge-pathnames ".parencade-save.sexp" (user-homedir-pathname))
  "Sexp over ASN.1: no extra dependency, trivially human-inspectable,
and the project is Lisp-native end to end — reading a save file with
PRIN1/READ costs nothing an ASN.1 codec wouldn't also need to pay for
in a much heavier form.")

(defun save-game-to-file (table-title game score &optional (path *default-save-path*))
  "Writes (TABLE-TITLE SCORE (GAME-SAVE-DATA GAME)) as a plain
S-expression. Returns PATH."
  (with-open-file (out path :direction :output :if-exists :supersede :if-does-not-exist :create)
    (prin1 (list :table-title table-title :score score :data (game-save-data game)) out))
  path)

(defun load-game-from-file (&optional (path *default-save-path*))
  "Returns (values table-title score data), or NIL if PATH doesn't exist."
  (when (probe-file path)
    (with-open-file (in path)
      (let ((saved (read in)))
        (values (getf saved :table-title) (getf saved :score) (getf saved :data))))))
