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
  "#51: records BUS.PUSHED and updates BUS.QUEUE_DEPTH (a gauge derived
from push/pop counts, not CHANL's own internal queue-count — that
symbol is unexported in CHANL's package, fragile to depend on across a
library update; tracking push/pop counts here is more robust and
portable, and gives the raw counters as a useful side benefit, not
just the derived depth)."
  (chanl:send (bus-topic bus topic) value)
  (mInc (format nil "bus.pushed.~(~A~)" topic))
  (mGaugeSet (format nil "bus.queue_depth.~(~A~)" topic)
             (float (btd topic) 1.0d0))
  value)

(defun bus-pop (bus topic)
  "Blocking receive. #51: records BUS.POPPED and updates
BUS.QUEUE_DEPTH, same rationale as BUS-PUSH."
  (prog1 (chanl:recv (bus-topic bus topic))
    (mInc (format nil "bus.popped.~(~A~)" topic))
    (mGaugeSet (format nil "bus.queue_depth.~(~A~)" topic)
               (float (btd topic) 1.0d0))))

(defun bus-try-pop (bus topic)
  "Non-blocking receive. Returns (values value received-p). #51:
records BUS.POPPED only on an actual receive, not on a miss — a
non-blocking poll that finds nothing pending isn't a real pop."
  (multiple-value-bind (value received-p) (chanl:recv (bus-topic bus topic) :blockp nil)
    (when received-p
      (mInc (format nil "bus.popped.~(~A~)" topic))
      (mGaugeSet (format nil "bus.queue_depth.~(~A~)" topic)
                 (float (btd topic) 1.0d0)))
    (values value received-p)))

(defun btd (topic)
  "btd = bus topic depth. Pushed minus popped for TOPIC — 0 if neither
counter exists yet (a topic never touched has depth 0, not a
NIL-arithmetic error). Genuinely hot (called on every push/pop above),
hence the acronym per the naming convention's own stated bar."
  (- (let ((c (gethash (format nil "bus.pushed.~(~A~)" topic) *metrics*)))
       (if c (mCounterValue c) 0))
     (let ((c (gethash (format nil "bus.popped.~(~A~)" topic) *metrics*)))
       (if c (mCounterValue c) 0))))

(defparameter *engine-bus* (make-bus)
  "The one bus instance every consumer shares — #22's async theme
generation is its first real consumer, not a scaffolded placeholder.
Eagerly created at load time (cheap — an empty hash table, no real
resources allocated until a topic is actually used), rather than
lazily constructed in MAIN, so every game's render layer can reference
it directly without threading a bus argument through every call site.")
