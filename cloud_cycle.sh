#!/usr/bin/env bash
# Stateless daily cycle. Expects in cwd: slowagent.pyz, config.yaml, state.json (from D1).
# Produces: handoff.json (state_json, scans_json, digest, summary) for the caller to write back to D1.
set -euo pipefail
python3 -c "import requests, yaml" 2>/dev/null || pip install -q --break-system-packages requests pyyaml
DATE=$(date -u +%Y-%m-%d)
python3 slowagent.pyz import-state --in state.json
LAST=$(python3 - <<'PY'
import json; d=json.load(open('state.json'))
ts=d.get('last_run_ts') or max([r['ts'] for r in d['tables'].get('regime',[])] or [''])
print(ts)
PY
)
if [ "${LAST:0:10}" = "$DATE" ]; then
  echo "already ran today ($LAST): settle + digest only"
  { echo "=== slowagent daily run $DATE (cloud, settle-only) ==="; python3 slowagent.pyz -q settle; echo; python3 slowagent.pyz -q digest --no-scan; } | tee digest.txt
else
  { echo "=== slowagent daily run $DATE (cloud) ==="; python3 slowagent.pyz -q settle; echo; python3 slowagent.pyz -q run; echo; python3 slowagent.pyz -q digest --no-scan; } | tee digest.txt
fi
python3 slowagent.pyz export-state --out state_out.json --scans-since "$LAST"
python3 - <<'PY'
import json, datetime as dt
st=json.load(open('state_out.json')); st['last_run_ts']=dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
scans=json.load(open('state_out.json.scans.json')); digest=open('digest.txt').read()
json.dump({'date':dt.date.today().isoformat(),'state_json':json.dumps(st,sort_keys=True,separators=(',',':')),'state_sha':st['sha256'],
           'scans_json':json.dumps(scans,separators=(',',':')),'n_scans':len(scans),'digest':digest},open('handoff.json','w'))
print('handoff.json written: state_sha',st['sha256'],'scans',len(scans),'digest bytes',len(digest))
PY
