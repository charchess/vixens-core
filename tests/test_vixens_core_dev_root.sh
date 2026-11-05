#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
overlay="${root}/argocd/overlays/dev"

[[ -f "${overlay}/kustomization.yaml" ]]
[[ -f "${overlay}/bootstrap-marker.yaml" ]]

grep -Fq 'namespace: argocd' "${overlay}/kustomization.yaml"
grep -Fq 'bootstrap-marker.yaml' "${overlay}/kustomization.yaml"
grep -Fq 'name: vixens-core-dev-bootstrap' "${overlay}/bootstrap-marker.yaml"
grep -Fq 'vixens.lab/environment: dev' "${overlay}/bootstrap-marker.yaml"

kustomize build "${overlay}" >/dev/null
printf 'PASS: vixens-core dev root overlay renders.\n'
