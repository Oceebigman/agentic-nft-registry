#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

RPC="${BSC_RPC_URL:-https://bsc-dataseed.bnbchain.org}"
ABI="registry/abi/AgenticCollection.json"
REGISTRY="registry/collections.json"

python3 - "$REGISTRY" <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
assert d["chainId"] == 56
assert len(d["collections"]) == 20
assert all(c["status"] in ("deployed", "pending_deployment") for c in d["collections"])
deployed = [c for c in d["collections"] if c["status"] == "deployed"]
pending = [c for c in d["collections"] if c["status"] == "pending_deployment"]
assert all(c.get("contractAddress") for c in deployed)
assert all(not c.get("contractAddress") for c in pending)
print(f"Registry structure: OK ({len(d['collections'])} collections, {len(deployed)} deployed, {len(pending)} pending)")
PY

for row in $(python3 - "$REGISTRY" <<'PY'
import json,sys
for c in json.load(open(sys.argv[1]))["collections"]:
    if c["status"] == "deployed":
        print(c["name"].replace(" ","_")+"|"+c["symbol"]+"|"+c["contractAddress"]+"|"+str(c["maxSupply"]))
PY
); do
  IFS='|' read -r name symbol address max_supply <<< "$row"
  echo "Checking $name ($address)"
  cast call "$address" "name()(string)" --rpc-url "$RPC"
  cast call "$address" "symbol()(string)" --rpc-url "$RPC"
  cast call "$address" "maxSupply()(uint256)" --rpc-url "$RPC"
  cast call "$address" "totalMinted()(uint256)" --rpc-url "$RPC"
  cast call "$address" "remainingSupply()(uint256)" --rpc-url "$RPC"
done

echo "Read-only registry checks complete."
