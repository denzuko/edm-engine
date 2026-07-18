# Metrics & observability — lightweight, OTEL-inspired instrumentation

Status: design proposal, not implemented. Written per direct request,
grounded in a real, immediate need: #50's startup CPU/memory
investigation had to resort to ad hoc `ps -T` snapshots and one-off
`get-internal-real-time` measurements this session, precisely because
no standing instrumentation existed to answer the question
systematically. This design is that missing tool, not a speculative
addition.

## What "OTEL-style" means here, and what it deliberately doesn't

OpenTelemetry's three pillars (traces, metrics, logs) are the right
*conceptual* model — named, timed, tagged operations instead of ad hoc
print statements or one-off profiling sessions. A full OTEL SDK
(collectors, network exporters, distributed trace context propagation)
would be genuine over-engineering for a local, single-process game
engine running at 60fps — there's no distributed system here, nothing
to propagate trace context *to*. This design borrows the model, not
the implementation: a lightweight, engine-native registry, in the same
spirit as this project's own "don't pull in a heavy dependency for a
simple need" discipline already applied elsewhere (#7's Serapeum
question, #8's Datalog restraint).

**Explicitly out of scope**: network export, distributed tracing,
OTLP protocol compliance, any actual OpenTelemetry library dependency.
If this project ever needs to export to a real observability backend
(unlikely for a local game engine, but not impossible for, say,
aggregate crash/performance telemetry from real players), that's a
distinct, much later problem — an export adapter on top of this
registry, not a redesign of it.

## Core data model

Three primitive types, matching OTEL's own metric-type distinctions
because they map to genuinely different questions, not for taxonomy's
own sake:

```lisp
;; a monotonically-increasing count -- "how many times has X happened"
(defstruct metric-counter (value 0 :type (unsigned-byte 64)))

;; a point-in-time value that can go up or down -- "what is X right now"
(defstruct metric-gauge (value 0.0d0 :type double-float))

;; a distribution of observed durations/sizes -- "how long does X take"
;; kept deliberately simple: running count/sum/min/max, not full
;; histogram buckets -- this genre's debugging needs (this session's
;; own #50 investigation) call for "what's the average and worst case,"
;; not percentile-accurate distributions a real APM tool would need
(defstruct metric-histogram
  (count 0 :type (unsigned-byte 64))
  (sum 0.0d0 :type double-float)
  (min nil :type (or null double-float))
  (max nil :type (or null double-float)))
```

**Tagging**: a dotted namespace, matching OTEL's own attribute
convention (`http.method`, `db.statement`) rather than this project's
existing `org.cispec.*` label system — deliberately a separate
convention, not forced into cispec's model, since cispec is about
asset/CI identity and this is runtime measurement, a different concern
entirely despite the superficial dotted-name similarity.

```lisp
;; illustrative names, not a final naming scheme
"bus.queue_depth"        ; gauge, tagged by topic
"bus.push_to_pop_latency" ; histogram, tagged by topic
"thread.worker_busy_time" ; histogram, tagged by worker id
"render.frame_time"       ; histogram
"audio.pattern_gen_time"  ; histogram -- the exact 44ms measurement
                          ; that motivated #22, now a standing metric
                          ; instead of a one-off finding
"gc.run_count"            ; counter
"gc.time_spent"           ; histogram
```

## Where this lives architecturally

Recording a metric (incrementing a counter, observing a duration) is
genuinely pure — a hash-table update, no raylib dependency — and
belongs in the tested core, same discipline that moved #23's
`LOG-CRASH` and #22's `THEME-PLAYBACK-DECISION` there rather than
leaving them in an untested I/O file:

```lisp
(defvar *metrics* (make-hash-table :test #'equal)
  "tag-string -> METRIC-COUNTER/GAUGE/HISTOGRAM")

(defun metric-increment (tag &optional (amount 1))
  ...)

(defun metric-observe (tag value)  ; for gauges and histograms
  ...)

(defmacro with-timed-metric (tag &body body)
  "Wraps BODY, records its wall-clock duration as a histogram
observation against TAG. The actual instrumentation primitive most of
the named areas below use directly."
  ...)
```

**Performance discipline for the metrics system itself, stated
explicitly**: recording a metric must be O(1) and cheap enough not to
distort what it's measuring — this system exists to answer performance
questions, and a metrics system that itself causes the slowdown it's
investigating would be self-defeating. A single hash-table lookup plus
a struct-slot update per observation, no allocation in the hot path
beyond what `WITH-TIMED-METRIC`'s own timing call requires (matching
the same "cheap, everything per-frame is O(1)" discipline #37 already
establishes for the style cascade).

## Instrumentation points, by named area

Grounded in what's actually built this session, not speculative:

- **Render/paint**: `render.frame_time` (wrapping `ARCADE-RENDER`
  itself), `render.draw_call_count`, `render.mode_switches` (GPU/CPU
  toggles, #10).
- **Thread performance**: `thread.worker_busy_time` /
  `thread.worker_idle_time`, tagged per `LPARALLEL` worker — directly
  answers #50's "are we correctly offloading to the bus/threads"
  question, rather than the ad hoc per-thread `ps -T` snapshot this
  session had to fall back on.
- **Memory performance**: `gc.run_count`, `gc.time_spent` (SBCL
  exposes this via `SB-EXT:*GC-RUN-TIME*` and GC hooks — a real,
  available source, not something to build from scratch), and
  `gc.bytes_allocated` sampled periodically, not every frame.
- **Timers**: `#45`'s `GAME-TIMER` primitive, `AI-TIMER`, and
  `TWEEN`/effect durations — `timer.active_count`,
  `effect.instances_active`.
- **VFX/GFX**: effect-sequence dispatch timing (`#45`'s
  `DEFEFFECT-SEQUENCE`/`DEFEFFECT-STATE`), shader compile/load timing
  (a real, one-time cost `ENSURE-*-SHADER` functions already pay
  lazily, currently unmeasured).
- **SFX**: `audio.pattern_gen_time` — the exact 44ms measurement that
  originally motivated #22 becomes a standing, always-available metric
  rather than a one-off finding buried in a past session's transcript.
- **Event bus processing**: `bus.queue_depth` per topic (a real gap —
  `BUS.LISP` currently has no introspection into how full a channel
  is), `bus.push_to_pop_latency` (wrapping `BUS-PUSH`/`BUS-POP`/
  `BUS-TRY-POP` to timestamp both ends).
- **Additional areas beyond what was explicitly named, worth
  including**: `save.io_time` (save/load file I/O, #9's real scope),
  `input.poll_time` (keyboard/gamepad polling cost, relevant once
  #39's local multiplayer lands with multiple device sources),
  `startup.phase_time` (window creation, kernel bring-up, first-theme
  generation — the exact first-few-cycles window #50 is concerned
  about, broken into named phases rather than measured as one
  undifferentiated startup cost).

## Inspection and export

**SWANK-queryable, the primary mechanism** — `*METRICS*` is a plain
global hash table; a live session can already inspect it directly the
same way this session's own SWANK-based verification (#22's async
theme check, #23's injected-error test, #30's live difficulty check)
already works, no new tooling required for that path.

**Log export for when a live session isn't available** — matching
#23's `LOG-CRASH` precedent (`~/.parencade-saves/`, sibling to but
distinct from save data): a `DUMP-METRICS` function writing the
current registry snapshot to `~/.parencade-saves/metrics.log`,
callable on demand or on a periodic timer, so a real player on real
(possibly weak, per #50's own concern) hardware can report a metrics
snapshot alongside a bug report without a developer needing to be
attached via SWANK at the time.

## The concrete first consumer, not a scaffolded system

#50's own investigation is the real, named justification: profiling
GC activity and thread offloading "during the first few cycles" is
exactly what `startup.phase_time`, `thread.worker_busy_time`, and
`gc.run_count`/`gc.time_spent` would make systematic and repeatable,
replacing the ad hoc measurement this session had to use. Scoping the
first real implementation slice against #50 directly — not the full
instrumentation list above at once — matches the same "prove against
one real thing first" discipline #22/#36/#37 already established this
session.

## Cross-references

Directly answers #50's methodology gap. Extends the pure/untested-I/O
split discipline from #22/#23. `audio.pattern_gen_time` makes #22's
own measured 44ms finding a standing metric. `bus.queue_depth`/
`bus.push_to_pop_latency` give `#22`'s bus real introspection it
currently lacks entirely. Connects to #45/#46 for VFX/effect timing
once those are implemented.

## Open questions, not resolved here

- Whether `WITH-TIMED-METRIC` should have zero overhead when metrics
  are "disabled" (a global toggle) versus always-on — leaning toward
  always-on given the stated cheapness requirement, but not decided.
- Exact GC-hook mechanism (SBCL-specific `SB-EXT` hooks vs. periodic
  polling of `(SB-EXT:GET-BYTES-CONSED)`) — needs a real implementation
  attempt to settle, not designed further here.
- Whether a lightweight in-game debug overlay (rendering key metrics
  as on-screen text, not a new UI system) is worth building once real
  data exists to display, or whether SWANK/log-export inspection is
  sufficient — deferring until there's a real need driving the answer.

Not implemented. Scoping the first real PR (against #50 specifically)
is the next step once this direction is confirmed.
