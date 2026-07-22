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

(defvar *play-tone-function* #'play-tone
  "The function PROCESS-AUDIO-EVENTS actually calls to play a resolved
cue — defaults to PLAY-TONE itself, overridable (dynamically rebound)
for testing without a real audio device, or for a future global-mute
feature; not just a test-only hack.")

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
             (when cue
               (apply *play-tone-function* cue)))))
