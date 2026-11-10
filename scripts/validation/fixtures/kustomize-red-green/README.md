# Kustomize RED/GREEN fixtures

- `green/` is a minimal ConfigMap Kustomization and must render.
- `red/` references a file that does not exist and must fail during `kustomize build`.

They contain no cluster credentials or runtime dependencies.
