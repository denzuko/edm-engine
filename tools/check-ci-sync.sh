#!/usr/bin/env bash
# Verifies .github/workflows/ci.yml is genuinely in sync with
# ci/package.lisp's own DEFWORKFLOW — the same class of anti-pattern
# as committing generated shader .fs/.vs output (#24/48f654b) or
# hand-rolling CI bootstrap instead of the standard toolchain (#16):
# a derived artifact drifting from its own real source because a
# human (or agent) regenerated it manually, once, and trusted that to
# stay correct, rather than the pipeline itself enforcing sync on
# every commit.
#
# This doesn't solve the deeper bootstrap circularity — GitHub Actions
# needs a valid, committed ci.yml to know what to run at all, so it
# can't regenerate its own workflow file from a job defined inside
# that same file before the file exists. What this DOES do: fail the
# build the moment ci.yml and ci/package.lisp disagree, so drift is
# caught immediately rather than silently accumulating until someone
# notices the two have diverged.
set -euo pipefail
cd "$(dirname "$0")/.."

# Set once per shell session, same as `nvm use` — not re-derived via
# `qlot exec` per command, which injects nothing extra for `ros`
# specifically (Roswell's own bootstrap already checks
# QUICKLISP_HOME itself; see docs/qlot-guide.md). Guarded so this
# script stays safely callable standalone, not only as a step within
# ci/package.lisp's own +PROVISION-AND-BUILD+, which already exports
# this before calling here.
: "${QUICKLISP_HOME:=$(pwd)/.qlot/}"
export QUICKLISP_HOME

cp .github/workflows/ci.yml /tmp/ci.yml.committed

ros run --eval '(push (truename ".") asdf:*central-registry*)' \
  --eval '(ql:register-local-projects)' \
  --eval '(ql:quickload :edm-engine/ci :silent t)' \
  --eval '(40ants-ci:generate :edm-engine)' \
  --eval '(uiop:quit 0)' > /dev/null

if ! diff -q /tmp/ci.yml.committed .github/workflows/ci.yml > /dev/null; then
  echo "DRIFT: .github/workflows/ci.yml does not match a fresh regeneration from ci/package.lisp"
  echo "Run: sbcl --load /path/to/quicklisp/setup.lisp --eval '(ql:quickload :edm-engine/ci)' --eval '(40ants-ci:generate :edm-engine)'"
  echo "--- diff ---"
  diff /tmp/ci.yml.committed .github/workflows/ci.yml || true
  cp /tmp/ci.yml.committed .github/workflows/ci.yml
  exit 1
fi

cp /tmp/ci.yml.committed .github/workflows/ci.yml
echo "ci.yml is in sync with ci/package.lisp"
