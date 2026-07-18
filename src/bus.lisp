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

(defparameter *engine-bus* (make-bus)
  "The one bus instance every consumer shares — #22's async theme
generation is its first real consumer, not a scaffolded placeholder.
Eagerly created at load time (cheap — an empty hash table, no real
resources allocated until a topic is actually used), rather than
lazily constructed in MAIN, so every game's render layer can reference
it directly without threading a bus argument through every call site.")
