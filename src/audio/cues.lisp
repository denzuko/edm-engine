(in-package :edm-engine/audio)

;;; #59's own named audio piece: "DSL-driven consumers for music,"
;;; applying the identical pattern #58 proved for save/load and #37
;;; proved for VFX — game logic pushes a semantic event (:GAME + :CUE,
;;; not a waveform/frequency/duration triple), a declarative mapping
;;; (DEFAUDIO-CUES) resolves it, PROCESS-AUDIO-EVENTS (the consumer)
;;; drains the bus and plays it. All 16 of the four games' own
;;; PLAY-TONE calls (checked directly, not estimated) are currently
;;; direct, inline, and scattered — this file proves the mechanism;
;;; real per-game retrofits are separate, tracked work, not implied
;;; done by this file existing.

(defvar *audio-cues* (make-hash-table :test 'equal)
  "Maps (GAME . CUE) conses to (WAVEFORM FREQUENCY DURATION) lists,
registered via DEFAUDIO-CUES.")

(defvar *play-tone-function* nil
  "The function PROCESS-AUDIO-EVENTS actually calls to play a resolved
cue. NIL by default — this file (EDM-ENGINE/AUDIO/TONE) is pure, no
raylib, no I/O (matching PLAY-TONE itself living in the separate
EDM-ENGINE/AUDIO system, the raylib playback boundary) — PLAYBACK.LISP
sets this to #'PLAY-TONE at its own load time, once raylib is
genuinely available. A NIL value means PROCESS-AUDIO-EVENTS correctly
no-ops (nothing to play through) rather than erroring, matching how a
headless/raylib-free test environment (CI's own RUN-TESTS job,
confirmed directly as the actual cause of a real regression this
fixes) needs to load and test this file's own logic without ever
requiring raylib at all.")

(defmacro defaudio-cues (game &body cues)
  "Registers each (CUE-KEYWORD WAVEFORM FREQUENCY DURATION) in CUES
under GAME in *AUDIO-CUES*, keyed on (GAME . CUE) so two different
games can reuse the same cue keyword for genuinely different tones
without colliding."
  `(progn
     ,@(loop for (cue waveform frequency duration) in cues
             collect `(setf (gethash (cons ,game ,cue) *audio-cues*)
                             (list ,waveform ,frequency ,duration)))))

(declaim (ftype (function (keyword keyword) t) resolve-audio-cue))
(defun resolve-audio-cue (game cue)
  "Returns (WAVEFORM FREQUENCY DURATION) for (GAME . CUE), or NIL if
never registered — a genuine NIL, not a signaled error, matching
LOAD-GAME-FROM-SLOT's own NIL-for-unavailable convention (#9) rather
than crashing over a missing or stale cue."
  (gethash (cons game cue) *audio-cues*))

(defun process-audio-events ()
  "Drains *ENGINE-BUS*'s :AUDIO topic, resolving each event's :GAME/
:CUE pair and playing it via *PLAY-TONE-FUNCTION* — a genuine no-op
for an unregistered cue, not a crash. Called from the main loop
alongside PROCESS-SAVE-GAME-EVENTS/PROCESS-LOAD-GAME-EVENTS."
  (loop for (event received-p) = (multiple-value-list
                                   (edm-engine:bus-try-pop edm-engine:*engine-bus* :audio))
        while received-p
        do (let ((cue (resolve-audio-cue (getf event :game) (getf event :cue))))
             (when (and cue *play-tone-function*)
               (apply *play-tone-function* cue)))))
