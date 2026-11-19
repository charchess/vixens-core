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

# BEGIN MIRA_CORE_CILIUM_LB_AUTOSYNC_CONTRACT
cilium_lb="${root}/argocd/overlays/prod/apps/cilium-lb.yaml"
test -f "$cilium_lb"
# Keep the candidate manifest exactly as reviewed; this lane changes only this test.
cmp -s "$cilium_lb" <(git -C "$root" show "5546e765f538d8ce179c91760750b393ca359499:argocd/overlays/prod/apps/cilium-lb.yaml")
grep -Fxq '  name: core-cilium-lb' "$cilium_lb"
grep -Fxq '  namespace: argocd' "$cilium_lb"
grep -Fxq '    argocd.argoproj.io/sync-wave: "-2" # Deploy before cilium-config (wave -1)' "$cilium_lb"
grep -Fxq '    - resources-finalizer.argocd.argoproj.io' "$cilium_lb"
grep -Fxq '  project: default' "$cilium_lb"
grep -Fxq '    repoURL: https://github.com/charchess/vixens-core.git' "$cilium_lb"
grep -Fxq '    targetRevision: prod-stable' "$cilium_lb"
grep -Fxq '    path: apps/00-infra/cilium-lb/overlays/prod' "$cilium_lb"
grep -Fxq '    server: https://kubernetes.default.svc' "$cilium_lb"
grep -Fxq '    namespace: kube-system' "$cilium_lb"
grep -Fxq '  syncPolicy:' "$cilium_lb"
grep -Fxq '    automated: {}' "$cilium_lb"
if grep -Eq '^[[:space:]]*(prune|selfHeal|allowEmpty|syncOptions|retry|hooks|force|replace):|argocd\.argoproj\.io/hook' "$cilium_lb"; then
  echo 'core-cilium-lb must not extend automated sync with destructive or hook options' >&2
  exit 1
fi
base='f629c6ce259bb5715c36ba4e12a751b111e36ebd'
git -C "$root" cat-file -e "${base}^{commit}"
mapfile -t changed < <(git -C "$root" diff --name-only "$base" | sort)
expected=(
  'argocd/overlays/prod/apps/cilium-lb.yaml'
  'tests/test_infra_prod_root_channel.sh'
)
if [[ "${changed[*]}" != "${expected[*]}" ]]; then
  printf 'unexpected PR107 final diff: %s\n' "${changed[*]}" >&2
  exit 1
fi
printf 'PASS: core-cilium-lb exact autosync contract and two-file scope.\n'
# END MIRA_CORE_CILIUM_LB_AUTOSYNC_CONTRACT
