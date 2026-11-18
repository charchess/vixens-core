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

# BEGIN MIRA_FABRIC_PROD_ROOT_AUTOSYNC_CONTRACT
fabric_application="${root}/argocd/overlays/prod/apps/fabric-prod-root.yaml"
test -f "$fabric_application"
grep -Fxq '  name: fabric-prod-root' "$fabric_application"
grep -Fxq '    repoURL: https://github.com/charchess/vixens-fabric.git' "$fabric_application"
grep -Fxq '    targetRevision: prod-stable' "$fabric_application"
grep -Fxq '    path: argocd/overlays/prod' "$fabric_application"
grep -Fxq '  syncPolicy:' "$fabric_application"
grep -Fxq '    automated: {}' "$fabric_application"
if grep -Eq '^[[:space:]]*(prune|selfHeal|allowEmpty):' "$fabric_application"; then
  echo 'fabric-prod-root must not enable prune, selfHeal, or allowEmpty' >&2
  exit 1
fi
printf 'PASS: fabric prod root tracks prod-stable with autosync only.\n'
# END MIRA_FABRIC_PROD_ROOT_AUTOSYNC_CONTRACT
