(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

;;; #64's own Hearts pilot — Consfigurator's structural pattern
;;; (declarative properties describing desired state, composed
;;; together, applied), not its literal API. Orchestrates the engine
;;; (phase transitions, bus dispatch) — never a game's own domain
;;; logic, which stays exactly what it already is: plain, directly-
;;; callable Lisp functions passed in by name as :GUARD/:EFFECT.
;;;
;;; Hard, non-negotiable constraint from docs/orchestration-dsl-
;;; design.md: macro-expansion only, never a runtime S-expression
;;; interpreter. Each :TRANSITION clause expands into a real, named
;;; DEFUN — checkable with MACROEXPAND-1, traceable with TRACE,
;;; visible to SWANK like any other function, because it IS just
;;; another function once expanded, not a data structure some
;;; separate engine walks at runtime.

(defmacro deforchestration (struct-name &body transitions)
  "For each (:TRANSITION NAME :FROM-PHASE FROM :TO-PHASE TO :GUARD
GUARD-FN :EFFECT EFFECT-FN :BUS-EVENT EVENT-PLIST) in TRANSITIONS,
defines TRY-STRUCT-NAME-NAME (GAME): if GAME's own PHASE accessor
reads FROM and (GUARD-FN GAME) is true, calls (EFFECT-FN GAME), sets
PHASE to TO, pushes EVENT-PLIST onto *ENGINE-BUS*'s :SEMANTIC topic,
and returns T; otherwise does nothing and returns NIL.

:SEMANTIC (not :AUDIO) per docs/semantic-event-architecture-design.md
— a meaningful game-state transition is not inherently an audio-only
concern; PROCESS-AUDIO-EVENTS is one of potentially several
reactors PROCESS-SEMANTIC-EVENTS fans this topic out to, not this
topic's sole reason to exist.

STRUCT-NAME must have a PHASE slot with the conventional DEFSTRUCT
accessor name STRUCT-NAME-PHASE (e.g. HEARTS-GAME-PHASE for
HEARTS-GAME) — this macro doesn't reach into slots by any other
means, matching the constraint that it never touches a game's own
domain logic, only its declared phase."
  `(progn
     ,@(loop for (transition-keyword name . plist) in transitions
             for phase-accessor = (intern (format nil "~A-PHASE" struct-name))
             for from-phase = (getf plist :from-phase)
             for to-phase = (getf plist :to-phase)
             for guard = (getf plist :guard)
             for effect = (getf plist :effect)
             for bus-event = (getf plist :bus-event)
             for fn-name = (intern (format nil "TRY-~A-~A" struct-name name))
             collect `(progn
                        (export ',fn-name)
                        (defun ,fn-name (game)
                          (when (and (eq (,phase-accessor game) ,from-phase)
                                     (funcall #',guard game))
                            (funcall #',effect game)
                            (setf (,phase-accessor game) ,to-phase)
                            (bus-push *engine-bus* :semantic (list ,@bus-event))
                            t))))))
