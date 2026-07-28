# Target architecture: one semantic event bus, independent workers, converged AI/human intent

Status: design proposal, not implemented. Written per direct
instruction, after reviewing `docs/systemic-event-bus-architecture.md`
and `docs/orchestration-dsl-design.md` first — this doc is their
natural continuation, not a break from them. Grounded in real,
current code, checked directly, not assumed.

## Three real findings that motivate this, all checked directly

**1. `process-audio-events` handles 24 event sites across 7 files
today** — every `bus-push ... :audio` call in `src/`, counted
directly, not estimated. It is correctly scoped to audio specifically
(it resolves a cue name to a tone and plays it) — the problem isn't
that it does too much, it's that **nothing else shares the event it's
draining.**

**2. `deforchestration` — the core orchestration macro — hardcodes its
generated transitions to push to `:audio` specifically**, not a
generic semantic topic. `src/orchestration.lisp`'s own expansion:
`(bus-push *engine-bus* :audio (list ,@bus-event))`. Every game's own
outcome (`hearts-round-outcome`, `queens-level-outcome`) is real
DSL-declared data — but the *only* consumer that data can ever reach,
by construction, is audio. A future VFX/analytics/network-sync
consumer wanting to react to "Hearts was won" has no bus topic to
drain; the DSL itself doesn't produce one for it.

**3. `:vfx` exists as a second, real topic — but has no shared worker
at all.** Confirmed directly: exactly one push site (Yahtzee's own
win transition) and exactly one drain site (Yahtzee's own
`GameOverlayEffects`, draining inline, not via a generic mechanism
matching `defaudio-cues`/`process-audio-events`'s own established
shape). The result: for the identical logical fact ("Yahtzee was
won"), the game's own code has two separate `bus-push` calls at the
same call site — one to `:audio`, one to `:vfx` — because the
producer has to know which consumers exist and address each one
directly. That's the actual leaky abstraction: **game logic should
emit that something happened, not know who's listening.**

This is precisely what `docs/systemic-event-bus-architecture.md`
already named as the target ("a declarative mapping from semantic
event to tone/pattern for audio, to layout position for rendering, to
effect sequence for VFX") — checked directly against what was actually
built, and confirmed as a real, current gap, not resolved by this
session's own DSL work so far.

## One pipeline, not two separate designs

An earlier draft of this doc split the semantic-event topic and the
intent-channel convergence into "piece 1, do now" and "piece 2,
design later" — a real mistake, corrected here directly rather than
left standing. They're two halves of the same pipeline (intent →
mutation → semantic event → reactions), not independent concerns;
designing one now and the other "later" risks the exact fragmentation
this session has already caught itself doing more than once — a
partial design treated as though the rest is optional, then never
actually revisited. Designed together below as one architecture.
Implementation can still land in stages (semantic-topic generalization
first, since it's the smaller, more mechanical change; intent
convergence second) — but the *design* itself isn't split.

One more precision worth stating plainly, since it's easy to
misread otherwise: "the producer shouldn't need to know who's
listening" is entirely about **local, same-process subscribers** —
confirmed directly, there is no networking code anywhere in this
codebase (`*engine-bus*` is `chanl`'s own intra-process channel
library). Yahtzee's own `:audio`/`:vfx` split is two workers in the
same running Lisp process, not a networked player receiving state
over the wire. A genuinely networked player — needing ordering
consensus across nodes, the kind a Raft-style replicated log solves —
is a real, different, much harder problem this local pub/sub bus does
not address and isn't claimed to. If networked multiplayer is ever
real scope, it needs its own design layered alongside this one, not
assumed to fall out of "one semantic event, many subscribers" for
free.

## The unified pipeline

```mermaid
flowchart LR
    subgraph producers["Intent producers"]
        Human["Human input\n(keypress)"]
        AI["AI decision\n(MAYBE-RUN-AI-TURN's own successor)"]
    end

    Human -->|"intent event"| IntentTopic[":INTENT topic"]
    AI -->|"intent event\n(the SAME shape as human's)"| IntentTopic
    IntentTopic --> IntentWorker["Intent worker\n(applies the mutation,\nonce, regardless of source)"]
    IntentWorker --> Orch["DEFORCHESTRATION / DEFOUTCOME\n(a game's own declared transitions)"]

    Orch -->|"ONE semantic event\n(e.g. :HEARTS :WON)"| SemanticTopic[":SEMANTIC topic"]

    SemanticTopic --> PAE["PROCESS-AUDIO-EVENTS\n(unchanged — still just a subscriber)"]
    SemanticTopic --> PVE["PROCESS-VFX-EVENTS\n(new — same shape as PAE,\nDEFVFX-CUES-style registry)"]
    SemanticTopic --> Future["Future LOCAL subscribers\n(analytics, replay —\nadded without touching producers)"]

    PAE --> Speaker(("🔊"))
    PVE --> Screen(("🎉"))
```

```mermaid
flowchart LR
    subgraph producers["Current state — confirmed by direct inspection, not idealized"]
        HP["Hearts: HEARTS-ROUND-OUTCOME"]
        YP["Yahtzee: win transition"]
    end

    HP -->|"bus-push :audio"| AudioTopic[":AUDIO topic"]
    YP -->|"bus-push :audio"| AudioTopic
    YP -->|"bus-push :vfx\n(a SECOND, separate call,\nsame logical event)"| VfxTopic[":VFX topic"]

    AudioTopic --> PAE["PROCESS-AUDIO-EVENTS\n(shared, generic worker)"]
    VfxTopic --> GOE["Yahtzee's own GAMEOVERLAYEFFECTS\n(inline, NOT shared/generic)"]

    PAE --> Speaker(("🔊"))
    GOE --> Screen(("🎉 confetti"))
```

## The design, in detail

**The semantic-event half.** `deforchestration`/`defoutcome`-driven
transitions push to a single, generic `:semantic` topic (event shape:
`(:game GAME :event NAME)`, already close to today's `(:game :hearts
:cue :won)` shape — a rename/generalization, not a redesign).
`process-audio-events` becomes one subscriber among several,
unchanged in its own logic — it already only cares about resolving a
`(game . cue)` pair, which doesn't need to know the topic is now
shared. A new, symmetric `defvfx-cues`/`process-vfx-events` (same
registry-macro shape as `defaudio-cues`/`process-audio-events`,
proven three times already this session for shaders/audio/theme-
sound) becomes Yahtzee's real target, replacing its own inline
`GameOverlayEffects` drain — and becomes available to Hearts/Queens/
Wordle's own win transitions for free, without those games' own code
needing to know VFX exists.

**The intent-convergence half.** Today, `maybe-run-ai-turn`'s own
decision (`ai-choose-play`, etc.) and a human's `key-enter` press
both end up calling the same mutating function (`play-card`,
`cycle-cell-at-cursor`) — but one path is a direct call from an AI
callback, the other a direct call from raylib's own input-polling
code. Both are real, valid inputs to "what should happen this frame"
— they're just not expressed as the same kind of thing today. Target:
both become the same shape — an intent event (`(:game GAME :intent
NAME :args ...)`) — pushed to a shared `:intent` topic. One worker
drains it and applies the mutation, regardless of whether the intent
came from a human keypress or an AI's own decision function.

**Why they're one design, not two.** The intent worker's own output
*is* what triggers `deforchestration`/`defoutcome` in the first
place — an applied intent is what makes a round-over or level-advance
transition become true, which is what produces the semantic event.
Designing the semantic-event shape without knowing what the intent
worker hands it, or designing the intent worker without knowing what
shape its own output needs to be for the orchestration layer to
consume, risks two halves that don't actually fit together — the
exact failure a split design invites.

## What this is not, stated per the same discipline as prior docs

Not a call to rewrite everything in one pass — matching
`docs/systemic-event-bus-architecture.md`'s own stated discipline, and
not a claim that networked multiplayer falls out of this design for
free (it doesn't — see above). The design itself is unified (intent →
mutation → semantic event → reactions, one coherent pipeline), but
implementation still lands in stages, same discipline as every real
lift this session has actually shipped: prove the smaller, more
mechanical piece against a real consumer first, generalize from there.

## Scope, for whoever picks this up

1. Rename/generalize `deforchestration`'s own hardcoded `:audio` push
   to a genuine `:semantic` topic (or similar), keeping the event
   shape close to today's for minimal churn — implemented first,
   since it's the smaller, more mechanical change.
2. Build `defvfx-cues`/`process-vfx-events`, proven against Yahtzee's
   own real `:yahtzee-won` VFX trigger as the first real retrofit —
   not built speculatively.
3. Confirm `process-audio-events` needs no logic change, only to keep
   subscribing to whatever the renamed/shared topic becomes.
4. Design and build the intent-event shape and its one shared,
   draining worker — informed by the semantic-event half already
   being real and proven by this point, not designed in the dark
   before any of it exists, but still the same unified architecture
   from the start, not an afterthought bolted on.
