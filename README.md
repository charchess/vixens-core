# vixens-core

Platform contracts: network, storage, certificates, secrets and policy primitives.

## Bootstrap status

This repository contains the Core-only Argo CD compositions for development and production. Every migrated child Application is deliberately **manual-sync** and has a `core-` identity, so it can be reviewed without colliding with the still-active monorepo Applications. It contains no credentials or runtime state.

## Non-goals

Shared product services, personal applications, TXO Fabric product manifests, Terraform/Talos bootstrap, and a live ArgoCD ownership handoff.

## CI scope

YAML and Kustomize rendering/schema checks for Core-owned content, plus targeted policy, network and storage contract validation when that content is introduced.

## Delivery model

Changes follow Issue → branch → PR → required CI → merge. The retained `charchess/vixens` repository remains the active GitOps authority until each workload undergoes an explicit, one-owner-at-a-time Argo CD handoff.
