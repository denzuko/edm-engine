# Naming convention: token-golfed identifiers, measured not guessed

Status: standing rule, in force. Written because this was established
three separate times across this project's history and lost each
time — this document exists specifically so a fourth correction is
never necessary.

## The actual rule

**No hyphens, no underscores in code identifiers.** Every hyphen or
underscore is very likely its own token under a BPE tokenizer,
independent of the words it separates — this is the real, measured
cost `kebab-case`/`snake_case` carries that plain word-concatenation
doesn't.

**Default: full-word camelCase.** `renderPatternAsync`,
`centeredGridPositions`, `metricIncrement`. Measured directly
(`tiktoken`, `o200k_base`, matching this project's own established
empirical methodology from the source thesis below) against the
kebab-case originals — full-word camelCase already captures most of
the available win, because common English word-fragments are
efficient, single tokens in most BPE vocabularies.

**Acronym-style compression (3-4 letters) for genuinely hot,
frequently-repeated names, where it's worth the readability cost.**
`rpa` (render-pattern-async), `cgp` (centered-grid-positions), `btd`
(bus-topic-depth). Measured to reliably land at 2 tokens, a real
floor.

**No reliable middle ground — measured, not assumed.** An earlier
draft of this rule proposed a "shortened but still multi-root" tier
(`thmPbkDec`, `mtrInc`) as a compromise between full camelCase and true
acronyms. Measuring it directly showed this tier is *inconsistent* —
in some cases actually worse than plain full-word camelCase, because
an arbitrary abbreviation doesn't match anything in the tokenizer's
own vocabulary and gets chopped into awkward, inefficient pieces. The
real choice is full-word camelCase or true acronym compression, not a
gradient between them.

## Locals and parameters

Standard, recognizable CS abbreviations, not invented ones: `dur`,
`amp`, `pos`, `n` (count), `i` (index), `prev`, `cfg`, `tmp`. These
were correct from the first draft of this rule and didn't change with
the measurement pass above.

## Scope: forward-applying, not retroactive

New code, always. Existing, already-committed code is renamed
opportunistically — whenever a file is already being touched for a
real reason (a bug fix, a retrofit, a feature), its identifiers come
into line with this rule as part of that change, not as a separate,
disruptive mass-rename pass across the whole codebase. Every commit's
diff stays honest — renames bundled with real work, not a giant
rename-only commit touching nothing else.

Common Lisp's own standard library and every third-party dependency
this project uses (`alexandria`, `serapeum`, `chanl`, `lparallel`,
`fiveam`, the raylib bindings, `uiop`) stay kebab-case, unchanged —
this rule applies to identifiers this project defines, never to
calling convention for code this project doesn't own.

## Why this matters beyond style — the real stakes

This project is standing evidence for a specific, published thesis:
["Lisp Beats Every Modern Language on Token
Cost"](https://dwightaspencer.com/posts/26-lisp-token-cost/) — that
Lisp's macro system, whitespace agnosticism, and implicit returns give
it a structural token-compression advantage when code is read and
written through an LLM's context window, as opposed to a human
maintainer's. This engine is meant to be citable, working proof of
that thesis in production, not just a game that happens to be written
in Lisp — naming convention is part of the evidence, not a style
preference layered on top of it. `token-golfed` (or `through token
golf`) is the correct usage; `token golf` is a discipline, not a verb
one "applies."

Given that, the performance-tracking issues already filed (#50, #51,
#52) carry more weight than ordinary hygiene — a slow or resource-
heavy Lisp game undermines the exact claim this project exists to
demonstrate, not just its own smoothness.

## Cross-references

Grounded in the measurement methodology from post 26's own BMAC
appendix (`tiktoken`/`o200k_base`, empirical not estimated). Connects
to #50/#51/#52 — reframed from ordinary performance work to evidence
supporting this project's own stated thesis.
