# Workflow

## Canonical path

```text
GitHub Issue → branch → Pull Request → required CI → merge to main
```

## Repository-local component release contract

`main` remains source preparation only until a separate approved Argo CD handoff exists. This repository has local tag-channel authority, not deployment authority:

1. After **Validate & Security** succeeds for a `main` push, `Tag dev candidate` creates or verifies an immutable `dev-vYYYY.MM.<PR-or-short-sha>` tag at that exact commit, then moves `dev-latest` to it.
2. Production promotion is an **explicit human action** through `Promote prod candidate`. It accepts one exact immutable dev candidate, verifies its format, existence, ancestry to `main`, and a successful exact `Validate & Security` `main` run. It creates or verifies the corresponding immutable `prod-vYYYY.MM.<PR-or-short-sha>` tag before moving only this repository's `prod-stable` tag, then reads both pointers back.
3. `dev-*` and `prod-*` immutable tags are never overwritten. `dev-latest` and `prod-stable` are the only movable channel pointers in this contract. Normal production promotion must not move `prod-stable` manually.

This contract does not activate, bypass, or replace any separate Argo CD handoff, orchestrator BOM approval, rollout, or physical validation. A successful tag promotion is repository release metadata only; deployment and platform-health proof remain separate gates.

## Approved Infra production-root handoff (#55)

`argocd/overlays/prod/apps/infra-prod-root.yaml` is the approved first
component handoff. It follows the repository-local
`charchess/vixens-infra:prod-stable` channel rather than an immutable SHA.
The tag must be read back before promotion; the child `argocd/overlays/prod`
catalog must be rendered and compared before changing this root. This handoff
does not authorize a Fabric or Perso production root, legacy-owner retirement,
stateful migration, or a broad Argo sync.

## Required review questions

1. Does the change stay within this repository's responsibility?
2. Are any new platform/service requirements declared through the contract model?
3. Does it alter an active Argo CD owner, a release BOM, stateful identity, or a security boundary? If yes, stop and use the dedicated orchestration/migration issue.
4. Are all applicable CI checks green, with no unexpected skipped required job?
