(defpackage :edm-engine/e2e
  (:use :cl)
  (:export
   #:with-x-display #:parse-display-string #:find-window-by-name #:send-key #:send-char #:send-text
   #:run-arcade-with-driver #:wait-for #:+key-return+ +key-escape+
   #:+key-up+ #:+key-down+ #:+key-left+ #:+key-right+ #:+key-backspace+))
(in-package :edm-engine/e2e)

(declaim (optimize (speed 1) (safety 3))) ; test code — clarity over speed

;; standard X11 keysymdef.h values — not CLX-specific, part of the X protocol
(defconstant +key-return+ #xff0d)
(defconstant +key-escape+ #xff1b)
(defconstant +key-backspace+ #xff08)
(defconstant +key-up+ #xff52)
(defconstant +key-down+ #xff54)
(defconstant +key-left+ #xff51)
(defconstant +key-right+ #xff53)

(defun parse-display-string (display-string)
  "Splits a DISPLAY env var value like \":99\" or \"host:99.0\" into
(values host display-number). XLIB:OPEN-DISPLAY wants these as separate
arguments — passing the whole string as the host makes CLX try to
resolve \":99\" as a DNS hostname, which fails outright."
  (let* ((colon (position #\: display-string))
         (host (if colon (subseq display-string 0 colon) display-string))
         (rest (if colon (subseq display-string (1+ colon)) "0"))
         (dot (position #\. rest))
         (number (parse-integer (if dot (subseq rest 0 dot) rest))))
    (values host number)))

(defmacro with-x-display ((display &optional (host-string "")) &body body)
  (let ((h (gensym)) (n (gensym)))
    `(multiple-value-bind (,h ,n) (parse-display-string ,host-string)
       (let ((,display (xlib:open-display ,h :display ,n)))
         (unwind-protect (progn ,@body)
           (xlib:close-display ,display))))))

(defun find-window-by-name (display name &key (timeout 15))
  "Polls the root window's children for a window whose NAME matches,
for up to TIMEOUT seconds. Returns the XLIB:WINDOW, or NIL."
  (let ((deadline (+ (get-universal-time) timeout))
        (root (xlib:screen-root (first (xlib:display-roots display)))))
    (loop
      (dolist (win (xlib:query-tree root))
        (when (ignore-errors (string= name (xlib:wm-name win)))
          (return-from find-window-by-name win)))
      (when (> (get-universal-time) deadline)
        (return-from find-window-by-name nil))
      (sleep 0.5))))

(defun send-key (display keysym &key (delay 0.03))
  "Synthesizes a real key press+release via the XTEST extension — this
is genuine X11 input delivery, the same path a physical keyboard uses,
not a shortcut through GAME-UPDATE or any pure state-transition function."
  (let ((keycode (xlib:keysym->keycodes display keysym)))
    (unless keycode (error "no keycode for keysym #x~X" keysym))
    (xlib/xtest:fake-key-event display keycode t)
    (xlib:display-finish-output display)
    (sleep delay)
    (xlib/xtest:fake-key-event display keycode nil)
    (xlib:display-finish-output display)
    (sleep delay)))

(defun send-char (display char)
  (let ((keysym (first (xlib:character->keysyms char))))
    (unless keysym (error "no keysym for character ~S" char))
    (send-key display keysym)))

(defun send-text (display string)
  (loop for ch across string do (send-char display ch)))

(defun run-arcade-with-driver (driver-fn)
  "Runs the arcade's real frame loop on the CALLING thread — GLFW
needs to be driven from the actual main OS thread, not a
bordeaux-threads worker, or window creation fails outright. DRIVER-FN
runs concurrently on a background thread once the live ARCADE-STATE
exists; it's called with (STATE STOP-FN) — no screenshot pixel-guessing
needed, DRIVER-FN can read (and the tests assert on) the same object
the game thread is mutating. Call STOP-FN to end the loop once the
driver's done."
  (let (state should-stop)
    (let ((driver-thread
            (bordeaux-threads:make-thread
             (lambda ()
               (wait-for (lambda () state) :timeout 20)
               (unwind-protect
                    (funcall driver-fn state (lambda () (setf should-stop t)))
                 (setf should-stop t)))
             :name "edm-engine-e2e-driver")))
      (edm-engine:open-window (format nil "~A" edm-engine:+engine-name+) 800 700)
      (unwind-protect
           (progn
             (setf state (edm-engine:make-arcade-state))
             (loop until (or (edm-engine:window-should-close-p) should-stop)
                   do (edm-engine:arcade-update state)
                      (edm-engine:arcade-render state 800 700)))
        (edm-engine:close-window))
      (bordeaux-threads:join-thread driver-thread))))

(defun wait-for (predicate &key (timeout 5) (interval 0.05))
  "Polls PREDICATE until it's true or TIMEOUT elapses. Returns the
predicate's value (so callers can use it directly), or NIL on timeout."
  (let ((deadline (+ (get-internal-real-time) (* timeout internal-time-units-per-second))))
    (loop
      (let ((result (funcall predicate)))
        (when result (return result)))
      (when (> (get-internal-real-time) deadline) (return nil))
      (sleep interval))))
