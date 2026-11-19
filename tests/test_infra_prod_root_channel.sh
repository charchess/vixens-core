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
