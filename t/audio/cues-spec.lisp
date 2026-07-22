(in-package :edm-engine/audio/tests)
(in-suite :edm-engine-audio)

;;; DEFAUDIO-CUES / PROCESS-AUDIO-EVENTS — #59's own named audio piece
;;; ("DSL-driven consumers for music"), applying the identical pattern
;;; #58 proved for save/load and #37 proved for VFX: game logic pushes
;;; a semantic event to the bus (here, :GAME + :CUE, not a waveform/
;;; frequency/duration triple), a declarative mapping (this macro)
;;; resolves it, a consumer drains the bus and plays it. All 16 of the
;;; four games' own PLAY-TONE calls are currently direct, inline, and
;;; scattered — none go through this yet; this file proves the
;;; mechanism, real per-game retrofits follow. BDD-first, written
;;; before DEFAUDIO-CUES/PROCESS-AUDIO-EVENTS exist.

(test defaudio-cues-registers-a-cue-resolvable-by-game-and-cue-keyword
  "GOAL: registration is keyed on (GAME . CUE), not CUE alone — two
different games can use the same cue keyword for genuinely different
tones (checked directly below, not assumed safe from namespacing
alone)."
  (defaudio-cues :spec-game-a
    (:die-held :square 500.0 0.04))
  (is (equal '(:square 500.0 0.04) (resolve-audio-cue :spec-game-a :die-held))))

(test defaudio-cues-keeps-different-games-own-cues-genuinely-separate
  "GOAL: the same cue keyword registered for two different games must
resolve to each game's own, distinct tone -- not the first
registration silently shadowing the second, or a shared, ambiguous
entry."
  (defaudio-cues :spec-game-a (:won :sine 1000.0 0.3))
  (defaudio-cues :spec-game-b (:won :sine 200.0 0.9))
  (is (equal '(:sine 1000.0 0.3) (resolve-audio-cue :spec-game-a :won)))
  (is (equal '(:sine 200.0 0.9) (resolve-audio-cue :spec-game-b :won))))

(test resolve-audio-cue-returns-nil-for-an-unregistered-cue
  "GOAL: an unregistered (GAME . CUE) pair is a genuine NIL, not a
signaled error -- PROCESS-AUDIO-EVENTS needs to treat a typo'd or
stale cue keyword as a harmless no-op, matching LOAD-GAME-FROM-SLOT's
own NIL-for-unavailable convention (#9) rather than crashing the main
loop over a missing sound."
  (is (null (resolve-audio-cue :spec-game-a :genuinely-never-registered))))

(test process-audio-events-plays-the-resolved-cue-for-a-pushed-event
  "GOAL: pushing a real :AUDIO event with :GAME/:CUE, then draining it,
must call PLAY-TONE with exactly the registered cue's own parameters
-- the actual end-to-end mechanism, not each half tested in isolation
and assumed to compose."
  (defaudio-cues :spec-game-c (:blip :square 300.0 0.02))
  (let ((calls nil))
    (edm-engine:bus-push edm-engine:*engine-bus* :audio (list :game :spec-game-c :cue :blip))
    (let ((edm-engine/audio:*play-tone-function*
            (lambda (waveform frequency duration &key (amplitude 0.5))
              (declare (ignore amplitude))
              (push (list waveform frequency duration) calls))))
      (process-audio-events))
    (is (equal '((:square 300.0 0.02)) calls))))

(test process-audio-events-does-not-signal-for-an-unregistered-cue
  "GOAL: the main loop must not crash over a missing/typo'd cue -- a
genuine, direct check that PROCESS-AUDIO-EVENTS itself handles the
NIL case, not just that RESOLVE-AUDIO-CUE returns NIL in isolation."
  (edm-engine:bus-push edm-engine:*engine-bus* :audio (list :game :spec-game-c :cue :never-registered))
  (finishes (process-audio-events)))
