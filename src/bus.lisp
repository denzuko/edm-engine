(in-package :edm-engine)


(defstruct (bus (:constructor %make-bus))
  "Thin name table over per-topic ChanL channels.
One bounded channel per topic, created lazily on first use."
  (topics (make-hash-table :test #'eq) :type hash-table)
  (capacity 256 :type fixnum))

(defun make-bus (&key (capacity 256))
  (%make-bus :capacity capacity))

(declaim (ftype (function (bus keyword) chanl:channel) bus-topic))
(defun bus-topic (bus topic)
  "Return TOPIC's channel, creating a bounded channel of BUS's capacity
on first reference."
  (ensure-gethash topic (bus-topics bus)
                   (make-instance 'chanl:bounded-channel
                                   :size (bus-capacity bus))))

(defun bus-push (bus topic value)
  (chanl:send (bus-topic bus topic) value)
  value)

(defun bus-pop (bus topic)
  "Blocking receive."
  (chanl:recv (bus-topic bus topic)))

(defun bus-try-pop (bus topic)
  "Non-blocking receive. Returns (values value received-p)."
  (chanl:recv (bus-topic bus topic) :blockp nil))
