#!/usr/bin/env bash
# Runs policy/gate.rego against this repo's own git-tracked files —
# not the working directory (which can hold untracked/generated
# artifacts a real CI checkout would never see, confirmed directly:
# generated shader .fs/.vs files still on disk after being untracked
# would otherwise show as clean when they shouldn't).
#
# DENY findings fail this script (and CI, once wired in as a step);
# WARN findings are printed but don't fail — see policy/gate.rego's
# own header for why: 39 real, pre-existing spec-coverage/declaim
# gaps exist as of this writing, tracked as their own, separate
# cleanup, not swept into a hard-blocking gate that would fail every
# future commit until all 39 are individually resolved.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 -c "
import json, subprocess
tracked = subprocess.run(['git', 'ls-files'], capture_output=True, text=True).stdout.strip().split(chr(10))
files = {}
for path in tracked:
    try:
        with open(path, 'r', errors='ignore') as f:
            files[path] = f.read()
    except Exception:
        pass
with open('/tmp/gate-input.json', 'w') as out:
    json.dump({'files': files}, out)
"

echo "--- policy/gate.rego: WARN (tracked, non-blocking) ---"
opa eval -i /tmp/gate-input.json -d policy/gate.rego "data.edm.engine.gate.warn" | python3 -c "
import json, sys
d = json.load(sys.stdin)
vals = d['result'][0]['expressions'][0]['value'] if d.get('result') else []
for v in sorted(vals):
    print('  WARN:', v)
print(f'{len(vals)} warning(s)')
"

echo "--- policy/gate.rego: DENY (blocking) ---"
DENY_JSON=$(opa eval -i /tmp/gate-input.json -d policy/gate.rego "data.edm.engine.gate.deny")
DENY_COUNT=$(echo "$DENY_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
vals = d['result'][0]['expressions'][0]['value'] if d.get('result') else []
for v in sorted(vals):
    print('  DENY:', v)
print(len(vals))
" | tee /dev/stderr | tail -1)

if [ "$DENY_COUNT" -gt 0 ]; then
  echo "$DENY_COUNT blocking violation(s) — failing"
  exit 1
fi
echo "0 blocking violations"
