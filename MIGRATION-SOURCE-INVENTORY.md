# Staged monorepo source inventory

These source blocks were copied from `charchess/vixens` at commit `c6aafee2c7a6c6d90aa9b43dece229568ee13c0c` to prepare the multi-repository split.

## Safety boundary

- This repository now carries Core-only Argo CD compositions for development and production, but every child Application is manual-sync and uses a separate `core-` identity.
- No root registration, promotion reference, live Kubernetes object, data, PVC, PV, database state or secret is moved by this source migration.
- A future live source handoff must follow the `argocd-stateful-ownership-transfer` procedure: one authority, no prune, no PVC recreation, exact render comparison, and live identity proof.

## Source blocks

- `apps/00-infra`
- `apps/01-storage`
- `apps/40-network/external-dns-gandi`
- `apps/40-network/external-dns-unifi`

`apps/_shared` is copied as a temporary local build dependency. Its long-term ownership and any public contract extraction remain part of the orchestrator/BOM design; no cross-repository mutable import is introduced here.
