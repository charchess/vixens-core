#!/usr/bin/env bash
# Offline RED/GREEN regression harness for Kustomize failure propagation.
# It does not invoke GitHub Actions, a Kubernetes cluster, or kubeconform.

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
FIXTURE=""
KUSTOMIZE_BIN=${KUSTOMIZE_BIN:-kustomize}

usage() {
  printf 'Usage: %s --fixture {green|red}\n' "$0" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --fixture)
      FIXTURE=${2:-}
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

case "$FIXTURE" in
  green|red) ;;
  *)
    usage
    exit 2
    ;;
esac

if ! command -v "$KUSTOMIZE_BIN" >/dev/null 2>&1; then
  printf 'ERROR: Kustomize executable not found: %s\n' "$KUSTOMIZE_BIN" >&2
  exit 2
fi

fixture_dir="$ROOT/scripts/validation/fixtures/kustomize-red-green/$FIXTURE"
red_tmp=""
if [ "$FIXTURE" = "red" ]; then
  red_tmp=$(mktemp -d)
  cp "$fixture_dir/fixture-kustomization.yaml" "$red_tmp/kustomization.yaml"
  fixture_dir="$red_tmp"
fi
workflow="$ROOT/.github/workflows/validate.yaml"
output=$(mktemp)
trap 'rm -f "$output"; if [ -n "${red_tmp:-}" ]; then rm -f "$red_tmp/kustomization.yaml"; rmdir "$red_tmp"; fi' EXIT

if "$KUSTOMIZE_BIN" build "$fixture_dir" >"$output" 2>&1; then
  if [ "$FIXTURE" = "red" ]; then
    printf 'RED fixture unexpectedly built successfully\n' >&2
    exit 1
  fi
  printf 'GREEN: Kustomize build succeeded\n'
else
  if [ "$FIXTURE" = "red" ]; then
    printf 'RED: Kustomize build failed as expected\n'
    exit 1
  fi
  printf 'GREEN fixture failed to build\n' >&2
  cat "$output" >&2
  exit 1
fi

# This is a static offline assertion of the application-overlay aggregation
# contract.  The workflow remains the source of executable CI behavior.
if grep -Fq 'if ! output=$(kustomize build --enable-helm "$dir" 2>&1 > /dev/null); then' "$workflow"   && grep -Fq 'Skipping empty Kustomization stub: $dir' "$workflow"   && grep -Fq 'exit 1' "$workflow"; then
  printf 'GREEN: workflow accumulator is fail-closed\n'
else
  printf 'workflow accumulator is not fail-closed\n' >&2
  exit 1
fi
