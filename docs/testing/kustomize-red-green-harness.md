# Kustomize RED/GREEN offline harness

This harness is a deterministic, local regression check for the application-overlay
failure aggregation in `.github/workflows/validate.yaml`. It is intentionally
outside GitHub Actions: it does not run a workflow, contact a cluster, or change
CI routing. The workflow remains the executable merge gate.

## Baseline

The baseline was captured from `main` at SHA
`27658a97ffbcce4277b9509369f7b66355a43783`.

- GitHub Actions run: [`42531058219`](https://github.com/charchess/vixens-core/actions/runs/42531058219)
- Job: `Kustomize render`
- Observed run conclusion: `success`

The harness proves both ends of the local contract against that workflow shape:

1. the `green` fixture renders successfully with Kustomize;
2. the deliberately malformed `red` fixture exits non-zero; and
3. the workflow source contains the fail-closed renderer (`kustomize build --enable-helm`), rejects unexpected render errors, and exits non-zero.

It is not a replacement for a GitHub Actions execution, kubeconform, PDB selector
validation, or a PR-level fast/full routing test.

## Run

Install Kustomize v5 locally, then run both commands from the repository root:

```bash
KUSTOMIZE_BIN=kustomize ./scripts/validation/run-kustomize-red-green-harness.sh --fixture green
KUSTOMIZE_BIN=kustomize ./scripts/validation/run-kustomize-red-green-harness.sh --fixture red
python3 -m unittest scripts.validation.tests.test_kustomize_red_green_harness -v
```

The red command is expected to fail and print `RED: Kustomize build failed as
expected`. The unit test treats that non-zero exit as the required result.

## Blocking / non-blocking matrix

| Condition | Classification | Expected result | Evidence |
|---|---|---|---|
| Application-overlay Kustomize build failure | Blocking | `Kustomize render` fails | RED fixture plus `FAILED=1` accumulator assertion |
| Application-overlay kubeconform failure | Blocking | validation function returns non-zero; aggregate job fails | workflow contract |
| Application-overlay PDB selector mismatch | Blocking | validation function returns non-zero; aggregate job fails | workflow contract |
| Invalid rendered ArgoCD domain label | Blocking | validation function returns non-zero; aggregate job fails | workflow contract |
| Explicit ArgoCD `Validate=false` resource | Non-blocking for kubeconform only | document is excluded from kubeconform; Kustomize render still must pass | workflow contract |
| Overlay rendering 0 rendered resources | Non-blocking warning | warning is emitted; overlay returns success | workflow contract |
| Helm-only application with an empty base | Non-blocking skip | skip is emitted; overlay returns success | workflow contract |
| Security best-practice findings from Checkov | Non-blocking | `checkov ... || true` continues | workflow contract |
| Container-image sample scan failure | Non-blocking | warning is emitted; image-scan job continues | workflow contract |

The matrix documents the behavior at the recorded baseline. Update the SHA, run,
job result, and assertions together whenever the validation contract changes.
