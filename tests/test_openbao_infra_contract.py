#!/usr/bin/env python3
"""Fail-closed static contract for ESO's distinct OpenBao paths."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / "apps/00-infra/openbao/base/cluster-secret-store.yaml"
POLICY = ROOT / "apps/00-infra/cilium-lb/overlays/prod/ccnp-allow-external-secrets-openbao.yaml"
KUSTOMIZATION = ROOT / "apps/00-infra/cilium-lb/overlays/prod/kustomization.yaml"

store = STORE.read_text()
policy = POLICY.read_text()
kustomization = KUSTOMIZATION.read_text()

def require(text, needle):
    if needle not in text:
        raise AssertionError(f"missing required contract: {needle}")

def forbid(text, needle):
    if needle in text:
        raise AssertionError(f"forbidden contract drift: {needle}")

# The shared ClusterSecretStore remains Infra-only and uses TLS with a
# non-secret ConfigMap CA reference. Its existing token reference is a contract,
# not a value to be read or changed.
for required in (
    "name: openbao",
    "server: https://openbao.truxonline.com",
    "path: kv",
    "version: v2",
    "caProvider:",
    "type: ConfigMap",
    "name: openbao-infra-ca",
    "key: ca.crt",
    "tokenSecretRef:",
    "namespace: external-secrets",
    "name: openbao-token",
    "key: token",
):
    require(store, required)
for forbidden in ("http://", ":8200", "tlsSkipVerify", "insecure", "fallback", "openbao-fabric"):
    forbid(store, forbidden)

# ESO keeps its private Fabric endpoint selector on TCP/8200, and adds a
# separate exact Infra FQDN/TLS rule plus only kube-dns UDP/TCP 53.
for required in (
    "name: allow-external-secrets-openbao",
    "k8s:app.kubernetes.io/name: openbao-fabric",
    'port: "8200"',
    "toFQDNs:",
    "matchName: openbao.truxonline.com",
    'port: "443"',
    "k8s:k8s-app: kube-dns",
    'port: "53"',
):
    require(policy, required)
for forbidden in ("toCIDR:", "toEntities:", "world", "matchPattern:", "*.truxonline.com", "http://", 'port: "8200"\n              protocol: TCP\n        - ports:\n            - port: "443"'):
    forbid(policy, forbidden)
require(kustomization, "ccnp-allow-external-secrets-openbao.yaml")

print("openbao infra contract: PASS")
