#!/usr/bin/env python3
"""Fail-closed contract for the Core OpenBao store Application autosync."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "argocd/overlays/prod/apps/openbao-secrets.yaml"
ROOT_KUSTOMIZATION = ROOT / "argocd/overlays/prod/kustomization.yaml"
text = APP.read_text()
root = ROOT_KUSTOMIZATION.read_text()

def require(needle):
    if needle not in text:
        raise AssertionError(f"missing required contract: {needle}")

def forbid(needle):
    if needle in text:
        raise AssertionError(f"forbidden contract drift: {needle}")

for required in (
    "apiVersion: argoproj.io/v1alpha1",
    "kind: Application",
    "name: core-openbao-secrets",
    "namespace: argocd",
    'argocd.argoproj.io/sync-wave: "-3"',
    "project: default",
    "repoURL: https://github.com/charchess/vixens-core.git",
    "targetRevision: prod-stable",
    "path: apps/00-infra/openbao/overlays/prod",
    "server: https://kubernetes.default.svc",
    "namespace: external-secrets",
    "syncPolicy:",
    "automated: {}",
):
    require(required)
if text.count("source:") != 1 or text.count("repoURL:") != 1:
    raise AssertionError("Application must retain exactly one source")
if text.count("syncPolicy:") != 1 or text.count("automated: {}") != 1:
    raise AssertionError("Application must declare exactly one empty automated policy")
for forbidden in (
    "prune:", "selfHeal:", "allowEmpty:", "syncOptions:", "retry:",
    "hooks:", "force:", "replace:", "sources:", "kind: ClusterSecretStore",
    "kind: ExternalSecret", "kind: Secret", "kind: Role", "kind: RoleBinding",
):
    forbid(forbidden)
if "  - apps/openbao-secrets.yaml" not in root:
    raise AssertionError("prod root must retain exactly the OpenBao Application entry")
print("openbao secrets autosync contract: PASS")
