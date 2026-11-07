#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
policy_dir="${root}/apps/00-infra/kyverno/base/policies"
prod_overlay="${root}/argocd/overlays/prod"

policy_rendered=$(mktemp)
prod_rendered=$(mktemp)
trap 'rm -f "${policy_rendered}" "${prod_rendered}"' EXIT

kustomize build "${policy_dir}" >"${policy_rendered}"
kustomize build "${prod_overlay}" >"${prod_rendered}"

grep -Fq 'name: mutate-truenas-csi-talos-hostpath' "${policy_rendered}"
grep -Fq -- '- synelia-prod-csi-node' "${policy_rendered}"
grep -Fq -- '- synelia-prod-csi' "${policy_rendered}"
grep -Fq 'value: iscsi-dir' "${policy_rendered}"
grep -Fq 'type: ""' "${policy_rendered}"

grep -Fq 'name: core-synelia-prod-csi' "${prod_rendered}"
grep -Fq '.spec.template.spec.volumes[] | select(.name == "iscsi-dir").hostPath.type' "${prod_rendered}"
grep -Fq 'RespectIgnoreDifferences=true' "${prod_rendered}"

printf 'PASS: TrueNAS CSI hostPath mutation is scoped and Argo-aware.\n'