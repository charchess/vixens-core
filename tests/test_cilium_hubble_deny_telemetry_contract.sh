#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PYTHON'
from pathlib import Path
import json

root = Path.cwd()
contract = (root / "contracts/cilium-hubble-deny-telemetry.yaml").read_text(encoding="utf-8")
service_monitor = (
    root / "apps/02-monitoring/victoria-metrics/base/servicemonitor-hubble.yaml"
).read_text(encoding="utf-8")
dashboard_manifest = (
    root / "apps/02-monitoring/grafana/base/dashboards/network-cilium-overview.yaml"
).read_text(encoding="utf-8")
dashboard = json.loads("{" + dashboard_manifest.split("    {", 1)[1])


def require(text: str, value: str, source: str) -> None:
    if value not in text:
        raise SystemExit(f"{source} is missing required deny-telemetry contract: {value!r}")


for value in (
    "kind: BoundedDenyTelemetryContract",
    'issue: "#96"',
    "maximumRetention: 10m",
    "medium: memory",
    "durablePersistence: prohibited",
    "export: prohibited",
    "backup: prohibited",
    "aggregateMetricsReader: monitoring/vmagent",
    "detailedCorrelationReader: incident-response/on-call",
    "detailedCorrelationAccess: break-glass, read-only, time-bounded",
    "hubble_flows_processed_total",
    "hubble_drop_total",
):
    require(contract, value, "Cilium/Hubble contract")

for forbidden_label in (
    "source",
    "destination",
    "source_namespace",
    "destination_namespace",
    "source_workload",
    "destination_workload",
    "source_pod",
    "destination_pod",
    "source_ip",
    "destination_ip",
    "source_port",
    "destination_port",
):
    require(contract, f"      - {forbidden_label}", "Cilium/Hubble contract")
    require(service_monitor, forbidden_label, "Hubble ServiceMonitor")

for value in (
    "metricRelabelings:",
    "action: keep",
    "regex: hubble_(flows_processed_total|drop_total)",
    "action: labeldrop",
):
    require(service_monitor, value, "Hubble ServiceMonitor")

if '"type":"loki"' in dashboard_manifest or '{job=\"hubble-flow\"}' in dashboard_manifest:
    raise SystemExit("network dashboard retains a durable detailed-flow drill-down")

allowed_metrics = {"hubble_flows_processed_total", "hubble_drop_total"}
for panel in dashboard.get("panels", []):
    for target in panel.get("targets", []):
        expression = target.get("expr", "")
        if "hubble_" not in expression:
            continue
        for metric in ("hubble_dns_responses_total", "hubble_tcp_flags_total", "hubble_lost_events_total"):
            if metric in expression:
                raise SystemExit(f"network dashboard retains a disallowed Hubble metric: {metric}")
        if not any(metric in expression for metric in allowed_metrics):
            raise SystemExit(f"network dashboard has an unapproved Hubble expression: {expression}")

variables = dashboard.get("templating", {}).get("list", [])
if any(variable.get("name") in {"loki_datasource", "rcode"} for variable in variables):
    raise SystemExit("network dashboard retains a detailed-flow datasource or DNS variable")

print("Cilium/Hubble bounded deny-telemetry contract: PASS")
PYTHON
