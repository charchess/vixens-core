# Synelia CSI: Kyverno hostPath drift

## Symptom

`core-synelia-prod-csi` is `OutOfSync` but `Healthy`; the only divergent resource is `DaemonSet/synelia-prod-csi-node`. Argo may complete automated syncs and retry self-heal without reaching `Synced`.

## Cause

The TrueNAS CSI chart v1.4.0 renders the named `iscsi-dir` volume with:

```yaml
hostPath:
  path: /etc/iscsi
  type: Directory
```

On Talos, Kyverno removes `hostPath.type` for this one volume. Ignoring only the scalar JQ result (`...hostPath.type`) did not suppress the resulting Argo diff.

## Canonical mitigation

The production Application ignores the **`hostPath` object only for the volume named `iscsi-dir`**:

```yaml
.spec.template.spec.volumes[] | select(.name == "iscsi-dir").hostPath
```

Do not widen this to all volumes, the whole DaemonSet, or a manager-wide ignore. The fixed path `/etc/iscsi` and the volume-name selector retain the intended boundary.

## Verification

After promoting the Git change, let the `prod-stable` autosync run. Verify:

```sh
kubectl get application core-synelia-prod-csi -n argocd \
  -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
# Expected: Synced Healthy
```

Also confirm the live volume remains limited to `/etc/iscsi` and that no other Application ignore rule changed.

## Rollback

Promote the prior immutable Core production tag or revert the Application manifest commit, then manually promote the resulting candidate.
