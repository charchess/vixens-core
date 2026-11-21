#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
application="${root}/argocd/overlays/prod/apps/infra-prod-root.yaml"

test -f "$application"
grep -Fq 'name: infra-prod-root' "$application"
grep -Fq 'repoURL: https://github.com/charchess/vixens-infra.git' "$application"
grep -Fq 'targetRevision: prod-stable' "$application"
grep -Fq 'path: argocd/overlays/prod' "$application"

# An immutable SHA bypasses Infra's local promotion channel.
if grep -Eq 'targetRevision: [0-9a-f]{40}$' "$application"; then
  echo 'infra-prod-root must track the approved repository-local prod-stable channel' >&2
  exit 1
fi

printf 'PASS: infra prod root tracks vixens-infra prod-stable.\n'

# Durable Cilium LB autosync safety invariants. These are manifest properties,
# not a PR-specific base/SHA/diff contract.
cilium_lb="${root}/argocd/overlays/prod/apps/cilium-lb.yaml"

test -f "$cilium_lb"
grep -Fxq '  name: core-cilium-lb' "$cilium_lb"
grep -Fxq '  namespace: argocd' "$cilium_lb"
grep -Fxq '    argocd.argoproj.io/sync-wave: "-2" # Deploy before cilium-config (wave -1)' "$cilium_lb"
grep -Fxq '    - resources-finalizer.argocd.argoproj.io' "$cilium_lb"
grep -Fxq '  project: default' "$cilium_lb"
grep -Fxq '  syncPolicy:' "$cilium_lb"
grep -Fxq '    automated:' "$cilium_lb"
grep -Fxq '      enabled: true' "$cilium_lb"
grep -Fxq '      prune: true' "$cilium_lb"
grep -Fxq '      selfHeal: true' "$cilium_lb"
grep -Fxq '    repoURL: https://github.com/charchess/vixens-core.git' "$cilium_lb"
grep -Fxq '    targetRevision: prod-stable' "$cilium_lb"
grep -Fxq '    path: apps/00-infra/cilium-lb/overlays/prod' "$cilium_lb"
grep -Fxq '    server: https://kubernetes.default.svc' "$cilium_lb"
grep -Fxq '    namespace: kube-system' "$cilium_lb"

if grep -Eq '^[[:space:]]*(allowEmpty|syncOptions|retry|hooks|force|replace):|argocd\.argoproj\.io/hook' "$cilium_lb"; then
  echo 'core-cilium-lb must not extend the mandatory production sync policy with extra destructive or hook options' >&2
  exit 1
fi

printf 'PASS: core-cilium-lb retains bounded automated sync safety invariants.\n'
