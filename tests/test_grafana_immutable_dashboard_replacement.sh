#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PYTHON'
from pathlib import Path
import json

manifest_path = Path.cwd() / "apps/02-monitoring/grafana/base/dashboards/network-cilium-overview.yaml"
manifest = manifest_path.read_text(encoding="utf-8")

expected_name = "grafana-dashboard-network-cilium-overview"
required_manifest_values = (
    "apiVersion: v1",
    "kind: ConfigMap",
    f"  name: {expected_name}",
    "    argocd.argoproj.io/sync-options: Force=true,Replace=true",
    "immutable: true",
    "  network-cilium-overview.json: |",
)
for value in required_manifest_values:
    if value not in manifest:
        raise SystemExit(f"dashboard ConfigMap is missing required value: {value!r}")

if f"  name: {expected_name}-v2" in manifest:
    raise SystemExit("dashboard ConfigMap name changed instead of being replaced")

try:
    dashboard_json = "{" + manifest.split("    {", 1)[1]
except IndexError as error:
    raise SystemExit("dashboard ConfigMap has no indented JSON payload") from error

try:
    dashboard = json.loads(dashboard_json)
except json.JSONDecodeError as error:
    raise SystemExit(f"dashboard ConfigMap payload is not valid JSON: {error}") from error

if not isinstance(dashboard, dict):
    raise SystemExit("dashboard JSON payload must be an object")
if not isinstance(dashboard.get("panels"), list) or not dashboard["panels"]:
    raise SystemExit("dashboard JSON payload must contain at least one panel")

print("Grafana immutable dashboard replacement contract: PASS")
PYTHON
