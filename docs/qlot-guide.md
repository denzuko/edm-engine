# Qlot reference

Indexed from qlot's own manual (`qlot-1.8.2/README.markdown`), annotated
with what's actually relevant to this project. Read this before touching
`qlfile`, `qlfile.lock`, or reaching for `qlot exec` — don't re-derive
the syntax from scratch each session.

## What qlot is, and why this project uses it

A project-local library installer on top of Quicklisp — like Bundler
(Ruby) or Carton (Perl). Quicklisp alone only lets you pin a *month* of
dist, meaning every dependency in a project moves together; qlot pins
each dependency independently via `qlfile` + `qlfile.lock`, and keeps
them in a project-local `.qlot/` directory instead of the global
Quicklisp install.

**Both `qlfile` and `qlfile.lock` are meant to be committed** — the
lock file is what makes `qlot install` reproducible for anyone who
clones the repo. (This project's lock file wasn't committed until
2026-07-13 — a real gap, not a stylistic choice; see git log.)

## The one command that matters most: `qlot exec`

```sh
qlot exec <command>
```

Sets up ASDF's source registries to point at the project-local
`.qlot/`, puts Roswell's `bin/` on `PATH`, then runs `<command>`.

**Use `qlot exec ros run <sbcl flags>`, not `qlot exec sbcl` directly.**
Both often work, but `ros run` is the documented, endorsed path and is
what's been verified end-to-end for this project (full test suite,
the standalone executable build). This was originally documented
wrong in this repo's own README — fixed 2026-07-13.

```sh
# tests
qlot exec ros run --non-interactive \
  --eval '(ql:quickload :edm-engine/tests/all)' \
  --eval '(asdf:test-system :edm-engine/tests/all)'

# building the standalone executable
qlot exec ros run --non-interactive \
  --eval '(ql:quickload :edm-engine)' \
  --eval '(asdf:make :edm-engine)'
```

Other useful `exec` invocations from the manual:
- `qlot exec ros emacs` — Emacs with only qlot-local systems visible to
  the inferior Lisp.
- `qlot exec ros build some-app.ros` — build a binary from exactly the
  versions fixed in `qlfile`/`qlfile.lock`. Worth revisiting for the
  post-1.0 relocatable-binary problem (issue #1) instead of
  `asdf:make` directly.

## `qlfile` syntax — the part that keeps needing re-lookup

One dist declaration per line: `<source> <project-name> [args...]`.

| Source | Syntax | Use for |
|---|---|---|
| `ql` | `ql <name> [<version>\|:latest\|:upstream]` | anything in base Quicklisp |
| `ultralisp` | `ultralisp <name> [<version>]` | anything only in Ultralisp — **see gotcha below** |
| `git` | `git <name> <url> [:ref/:branch/:tag <val>]` | a specific git repo, any host |
| `github` | `github <user>/<repo> [:ref/:branch/:tag <val>]` | GitHub specifically — no `git` binary needed, uses the API (rate-limited to 60/hr unless `GITHUB_TOKEN` is set) |
| `http` | `http <name> <url> [<md5>]` | a tarball |
| `local` | `local <name> <path>` | a local directory, added to ASDF's source registry |
| `dist` | `dist <url> [<version>]` | a whole custom Quicklisp dist (e.g. `dist http://dist.ultralisp.org/`) |
| `ql-dist` | `ql-dist <dist-name> <name> [<version>]` | pick a specific project from a `dist` declared elsewhere in the same file, overriding normal priority |
| `asdf` | `asdf <version>` | pin a specific ASDF version (experimental) |

Lower entries in `qlfile` take priority over higher ones when multiple
distributions provide the same library.

### Gotcha: Ultralisp project names don't always match the base package name

`ultralisp screamer` failed here with:
```
qlot: 'screamer' is not available in dist '...'.
Did you mean:
  nikodemus-screamer
```
Ultralisp namespaces some packages by author/repo, not just the system
name. **When `ultralisp <name>` fails, qlot's own error message
suggests the corrected name — read it, don't guess a second name
blindly.** This project's `qlfile` uses `ultralisp nikodemus-screamer`
for `screamer` (Queens' board-generation dependency) for exactly this
reason.

## Commands reference

```sh
qlot init                    # scaffold qlfile/qlfile.lock/.qlot/ in a new project
qlot install                 # install per qlfile, preferring qlfile.lock if present
qlot install --no-cache      # skip the shared ~/.cache/qlot/ cache for this run
qlot update [name...]        # update (optionally scoped) deps, rewrites qlfile.lock
qlot add <name> [--latest|--upstream|--branch <b>]   # add + qlot install
qlot add <user>/<repo>       # add from GitHub shorthand
qlot remove <name...>        # remove + qlot install
qlot check                   # verify dependencies are satisfied
qlot outdated                # check for available updates
qlot bundle [--exclude <sys>] [--output <dir>]  # copy all deps into a
                              # self-contained directory (default
                              # .bundle-libs/) — runnable without qlot
                              # or Quicklisp at runtime at all; relevant
                              # to the relocatable-binary problem in
                              # issue #1, not yet explored
```

## Shared dependency cache

`~/.cache/qlot/` — deps are symlinked from here across projects that
use the same version, not re-downloaded per project. `rm -rf
~/.cache/qlot/` to clear it if something's stuck; `qlot install` will
repopulate it.

## Requirements

Roswell or plain SBCL, plus OpenSSL (`apt install libssl-dev` on
Debian/Ubuntu) and `git` for git-sourced dependencies.

## Known fragility (from GH issue #4)

`qlot install` hit a fatal low-level SBCL fault (`GC invariant lost`,
`coreparse.c` line 1450) inside Roswell's qlot subprocess on one real
machine (SBCL 2.6.5). Not reproduced in a fresh sandbox install on
SBCL 2.6.6 — looks environment/state-specific rather than a general
qlot/SBCL-2.6.x incompatibility, but plain Quicklisp (documented in
the main README as a fallback) is the answer if `qlot install` itself
won't complete on a given machine.
