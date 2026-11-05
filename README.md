# vixens-core

Platform contracts: network, storage, certificates, secrets and policy primitives.

## Bootstrap status

This repository is a **no-cutover bootstrap**. It is not an active Argo CD source and contains no copied production manifests, credentials or runtime state.

## Non-goals

Shared product services, personal applications, TXO Fabric product manifests, ArgoCD release composition and Terraform/Talos bootstrap.

## CI scope

YAML and Kustomize rendering/schema checks for Core-owned content, plus targeted policy, network and storage contract validation when that content is introduced.

## Delivery model

Changes follow Issue → branch → PR → required CI → merge. The retained `charchess/vixens` repository remains the future multi-repository GitOps orchestrator and release/BOM authority.
