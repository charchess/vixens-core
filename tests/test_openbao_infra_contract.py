#!/usr/bin/env python3
"""Fail-closed static contract for ESO's distinct OpenBao paths and DNS lanes."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / "apps/00-infra/openbao/base/cluster-secret-store.yaml"
POLICY = ROOT / "apps/00-infra/cilium-lb/overlays/prod/ccnp-allow-external-secrets-openbao.yaml"
COREDNS = ROOT / "apps/00-infra/cilium-lb/overlays/prod/ccnp-allow-coredns.yaml"
KUSTOMIZATION = ROOT / "apps/00-infra/cilium-lb/overlays/prod/kustomization.yaml"

store = STORE.read_text()
policy = POLICY.read_text()
coredns = COREDNS.read_text()
kustomization = KUSTOMIZATION.read_text()

PUBLIC = "openbao.truxonline.com"
FABRIC = "openbao-fabric.txo-fabric-system.svc"
DNS_NAMES = (
    f"{PUBLIC}.external-secrets.svc.cluster.local",
    f"{PUBLIC}.svc.cluster.local",
    f"{PUBLIC}.cluster.local",
    PUBLIC,
    f"{FABRIC}.external-secrets.svc.cluster.local",
    f"{FABRIC}.svc.cluster.local",
    f"{FABRIC}.cluster.local",
)


def require(text, needle):
    if needle not in text:
        raise AssertionError(f"missing required contract: {needle}")


def forbid(text, needle):
    if needle in text:
        raise AssertionError(f"forbidden contract drift: {needle}")


# The shared ClusterSecretStore uses public system trust. Its token reference is
# a contract only; this test neither reads nor changes any token value.
for required in (
    "name: openbao", "server: https://openbao.truxonline.com", "path: kv",
    "version: v2", "tokenSecretRef:", "namespace: external-secrets",
    "name: openbao-token", "key: token",
):
    require(store, required)
token_block = """tokenSecretRef:
          namespace: external-secrets
          name: openbao-token
          key: token"""
if store.count("server: https://openbao.truxonline.com") != 1:
    raise AssertionError("expected exactly one strict Infra server")
if store.count(token_block) != 1:
    raise AssertionError("expected exactly one preserved token reference")
for forbidden in ("caProvider:", "openbao-infra-ca", "http://", ":8200", "tlsSkipVerify", "insecure", "fallback", "openbao-fabric"):
    forbid(store, forbidden)

# The exact complement of ESO controller identity is represented as two positive
# global DNS selectors: non-ESO namespaces, plus non-controller endpoints in
# the ESO namespace. This avoids a union-shaped NotIn exclusion.
forbid(coredns, "endpointSelector: {}")
forbid(coredns, "operator: NotIn\n        values:\n          - external-secrets\n      - key: io.kubernetes.pod.namespace")
for required in (
    "name: allow-coredns-egress",
    "specs:",
    "key: io.kubernetes.pod.namespace\n          operator: NotIn",
    "matchLabels:\n        io.kubernetes.pod.namespace: external-secrets",
    "key: app.kubernetes.io/name\n          operator: NotIn",
    "k8s:k8s-app: kube-dns",
    'port: "53"',
):
    require(coredns, required)
if coredns.count("operator: NotIn") != 2:
    raise AssertionError("CoreDNS exact-complement contract requires two positive lanes")
if coredns.count("k8s:k8s-app: kube-dns") != 2:
    raise AssertionError("each exact-complement lane must retain CoreDNS selection")

# Semantic inventory of the two selectors: only the exact ESO controller pair
# is absent from global L3/L4 DNS. Webhook, cert-controller, and an app sharing
# the ESO name in another namespace remain globally selected.
def global_dns_selected(namespace, app_name):
    return namespace != "external-secrets" or (
        namespace == "external-secrets" and app_name != "external-secrets"
    )

for name, namespace, app_name, expected in (
    ("eso-controller", "external-secrets", "external-secrets", False),
    ("eso-webhook", "external-secrets", "external-secrets-webhook", True),
    ("cert-controller", "cert-manager", "cert-manager", True),
    ("same-app-other-namespace", "default", "external-secrets", True),
):
    if global_dns_selected(namespace, app_name) != expected:
        raise AssertionError(f"global DNS selector semantics drifted for {name}")

# ESO keeps a private Fabric TCP/8200 selector lane and one bare public FQDN
# TLS/443 lane. DNS is constrained at L7 to the seven approved resolver names.
for required in (
    "name: allow-external-secrets-openbao",
    "k8s:app.kubernetes.io/name: openbao-fabric",
    'port: "8200"', "toFQDNs:", "matchName: openbao.truxonline.com",
    'port: "443"', "k8s:k8s-app: kube-dns", 'port: "53"',
    "rules:\n            dns:",
):
    require(policy, required)
if policy.count("toFQDNs:") != 1 or policy.count("matchName: openbao.truxonline.com\n") != 2:
    raise AssertionError("only bare public OpenBao may remain in the TCP/443 FQDN lane and L7 DNS rule")
if policy.count('port: "8200"') != 1:
    raise AssertionError("Fabric TCP/8200 lane must remain singular")

try:
    dns_block = policy.split("rules:\n            dns:\n", 1)[1]
except IndexError as exc:
    raise AssertionError("ESO DNS must use L7 rules.dns") from exc
if dns_block.count("matchName:") != 7:
    raise AssertionError("ESO DNS must declare exactly seven L7 names")
for name in DNS_NAMES:
    require(dns_block, f"matchName: {name}")
for forbidden in (
    f"matchName: {FABRIC}\n", "toCIDR:", "toEntities:", "world",
    "matchPattern:", "*.truxonline.com", "http://", "serverNames:",
):
    forbid(policy, forbidden)

require(kustomization, "ccnp-allow-coredns.yaml")
require(kustomization, "ccnp-allow-external-secrets-openbao.yaml")
print("openbao infra DNS contract: PASS")
