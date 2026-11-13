---
type: "Runbook"
title: "Add a workload"
description: "Add a workload under apps/<namespace>/<name>/, then run make sync."
tags: [playground, workload]
status: stable
generated: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
verified: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
stale_after: 2027-05-11T00:00:00Z
---

# Add a workload

Last updated: 2026-11-12

A workload is a program the workshop runs in the Playground.
The directory is `apps/<namespace>/<name>/`.
`<namespace>` is the namespace.
`<name>` is the workload name.
Namespace `app-sandbox` is the directory `apps/app-sandbox/`.
podinfo is `apps/app-sandbox/sandbox-podinfo/`.
The Cache is `apps/app-sandbox/valkey/`.
The Database is `apps/app-sandbox/postgres/`.
Each kind has its own file, as in `apps/app-sandbox/valkey/`.
One `resources.yml` holds every kind when those kinds stay together.
podinfo and the Cache are the two shapes.

One Mac has one Playground.
The Cluster name is `playground`.
`container k8s` creates that Cluster.
You change files in Git.
Flux reconciles each workload directory.
Passwords and the CA stay in `.local/`.
Git ignores `.local/`.

Namespace `app-bank` is the directory `apps/app-bank/`.
`bank-postgres` holds the cluster files in `apps/app-bank/bank-postgres/`.
Each bank workload is a directory `apps/app-bank/bank-<name>/`, such as `apps/app-bank/bank-frontend/`.
Flux Kustomization `app-sandbox` reconciles `./apps/app-sandbox`.
Flux Kustomization `app-bank` reconciles `./apps/app-bank`.
Each workload has its own Flux Kustomization.

## The directory

When `<namespace>` is `app-bank`, use directory `apps/app-bank/bank-<name>/` where a step shows `apps/<namespace>/<name>/`.

1. Run `mkdir -p apps/<namespace>/<name>`.
   When `ls -d apps/<namespace>/<name>` prints that path, this step is complete.
2. If `apps/<namespace>/kustomization.yaml` is missing, create it with this file.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: <namespace>
resources: []
```

When that file sets `namespace` to `<namespace>`, this step is complete.
3. If `apps/<namespace>/namespace.yaml` is missing, create it with this file.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: <namespace>
  labels:
    app.kubernetes.io/part-of: playground
```

When the Namespace name is `<namespace>`, this step is complete.
Namespace `apps` comes from `apps/namespace.yaml`.
4. If you created `namespace.yaml`, add `- namespace.yaml` under `resources`.
   When `apps/<namespace>/kustomization.yaml` lists that file, this step is complete.
5. If `apps/kustomization.yaml` does not list `<namespace>/ks.yaml`, add `- <namespace>/ks.yaml` under `resources`.
   When that file lists `<namespace>/ks.yaml`, this step is complete.

## In the Cluster

When the workload has no hostname on the Gateway, do the steps in this section.
This section copies `apps/app-sandbox/valkey/`.

1. Copy `apps/app-sandbox/valkey/deployment.yaml` to `apps/<namespace>/<name>/deployment.yaml`.
   When the new file exists, this step is complete.
2. Copy `apps/app-sandbox/valkey/service.yaml` to `apps/<namespace>/<name>/service.yaml`.
   When the new file exists, this step is complete.
3. Copy `apps/app-sandbox/valkey/kustomization.yaml` to `apps/<namespace>/<name>/kustomization.yaml`.
   When the new file lists `deployment.yaml` and `service.yaml`, this step is complete.
4. In `kustomization.yaml`, set `namespace` to `<namespace>`.
   When that field is `<namespace>`, this step is complete.
5. In `deployment.yaml` and `service.yaml`, set `metadata.name` to `<name>`.
   When both names are `<name>`, this step is complete.
6. In those files, set every `app.kubernetes.io/name` value to `<name>`.
   When those lines show `<name>`, this step is complete.
7. In `deployment.yaml`, set `image` to the image for this workload.
   When the image line names that image, this step is complete.
8. In `deployment.yaml`, set `containerPort` to the port this workload listens on.
   When that line shows the port, this step is complete.
9. In `service.yaml`, set `port` to that same port.
   When the Service port matches `containerPort`, this step is complete.
10. In `service.yaml`, set `targetPort` to the container port's `name`.
    When `targetPort` matches that name, this step is complete.
11. In `deployment.yaml`, set both probes to a check for this process, as in `apps/app-sandbox/valkey/deployment.yaml`.
    When the probe calls this process, this step is complete.
12. If the image runs as root, delete the `securityContext` block from `deployment.yaml`.
    When a root image has no `securityContext` block, or a non-root image still has that block, this step is complete.
13. Leave `<name>` off `apps/<namespace>/kustomization.yaml`.
    When that file does not list `<name>`, this step is complete.

## Opened from the Mac

When the workload has a hostname on the Gateway, do the steps in this section.
Copy one podinfo file for each kind below.
The URL is `https://<name>.localhost:8443`.
`make up` already publishes port 8443.
Each listener on Gateway `playground` has one hostname.

1. Copy `apps/app-sandbox/sandbox-podinfo/deployment.yaml` to `apps/<namespace>/<name>/deployment.yaml`.
   When the new file exists, this step is complete.
2. Copy `apps/app-sandbox/sandbox-podinfo/service.yaml` to `apps/<namespace>/<name>/service.yaml`.
   When the new file exists, this step is complete.
3. Copy `apps/app-sandbox/sandbox-podinfo/certificate.yaml` to `apps/<namespace>/<name>/certificate.yaml`.
   When the new file exists, this step is complete.
4. Copy `apps/app-sandbox/sandbox-podinfo/httproute.yaml` to `apps/<namespace>/<name>/httproute.yaml`.
   When the new file exists, this step is complete.
5. Create `apps/<namespace>/<name>/kustomization.yaml` with this file.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: <namespace>
resources:
  - deployment.yaml
  - service.yaml
  - certificate.yaml
  - httproute.yaml
```

When the file lists those four files, this step is complete.
6. In `deployment.yaml`, `service.yaml`, and `certificate.yaml`, set `metadata.name` to `<name>`.
   When those names are `<name>`, this step is complete.
7. In `httproute.yaml`, set the redirect route name to `<name>-redirect`.
   When that name is `<name>-redirect`, this step is complete.
8. In `httproute.yaml`, set the second `metadata.name` to `<name>`.
   When that name is `<name>`, this step is complete.
9. In `deployment.yaml` and `service.yaml`, set every `app.kubernetes.io/name` value to `<name>`.
   When those lines show `<name>`, this step is complete.
10. In `deployment.yaml`, set `image` to the image for this workload.
    When the image line names that image, this step is complete.
11. If this workload has its own command, set `command` in `deployment.yaml`.
    When `command` matches this workload, this step is complete.
12. If the image already starts the process, delete `command` from `deployment.yaml`.
    When `command` is absent, this step is complete.
13. If this workload has arguments, set `args` in `deployment.yaml`.
    When `args` match this workload, this step is complete.
14. If this workload has no arguments, delete `args` from `deployment.yaml`.
    When `args` is absent, this step is complete.
15. In `deployment.yaml`, set `containerPort` to the port this workload listens on.
    When that line shows the port, this step is complete.
16. In `service.yaml`, set `port` to that same port.
    When the Service port matches `containerPort`, this step is complete.
17. In `service.yaml`, set `targetPort` to the container port's `name`.
    When `targetPort` matches that name, this step is complete.
18. In `deployment.yaml`, set both probes to a check for this process, as in `apps/app-sandbox/sandbox-podinfo/deployment.yaml`.
    When the probe calls this process, this step is complete.
19. If the image runs as root, delete the `securityContext` block from `deployment.yaml`.
    When a root image has no `securityContext` block, or a non-root image still has that block, this step is complete.
20. In `certificate.yaml`, set `secretName` to `<name>-tls`.
    When `secretName` is `<name>-tls`, this step is complete.
21. In `certificate.yaml`, set `dnsNames` to `<name>.localhost`.
    When `dnsNames` is `<name>.localhost`, this step is complete.

`issuerRef` in `certificate.yaml` stays `playground` and `ClusterIssuer`.

22. In `apps/app-sandbox/sandbox-podinfo/gateway.yaml`, duplicate the listener named `http` after the listener named `bank-https`.
    When a second listener has `name: http`, this step is complete.
23. Set the new listener's `name` to `<name>-http`.
    When that listener name is `<name>-http`, this step is complete.
24. Set the new listener's `hostname` to `<name>.localhost`.
    When that hostname is `<name>.localhost`, this step is complete.
25. In that file, duplicate the listener named `https` after the listener named `<name>-http`.
    When a second listener has `name: https`, this step is complete.
26. Set the new listener's `name` to `<name>-https`.
    When that listener name is `<name>-https`, this step is complete.
27. Set the new listener's `hostname` to `<name>.localhost`.
    When that hostname is `<name>.localhost`, this step is complete.
28. Set the new listener's `certificateRefs` name to `<name>-tls`.
    When that name is `<name>-tls`, this step is complete.
29. If `<namespace>` is not `apps`, set `allowedRoutes` on the new listeners from the listener `bank-http`.
    When the new listeners use that `selector`, this step is complete.
30. In `httproute.yaml`, set the first `sectionName` to `<name>-http`.
    When that `sectionName` is `<name>-http`, this step is complete.
31. Set the second `sectionName` to `<name>-https`.
    When that `sectionName` is `<name>-https`, this step is complete.
32. In `httproute.yaml`, replace `podinfo.localhost` with `<name>.localhost`.
    When `git diff` shows `<name>.localhost`, this step is complete.
33. If `<namespace>` is not `apps`, set `namespace: apps` on each `parentRef` in `httproute.yaml`.
    The bank routes in `apps/app-bank/bank-frontend/httproute.yaml` use that field.
    When each `parentRef` names namespace `apps`, this step is complete.
34. In `httproute.yaml`, set `backendRefs` name to `<name>`.
    When that name is `<name>`, this step is complete.
35. Set `backendRefs` port to the Service port.
    When that port matches the Service, this step is complete.
36. Leave `<name>` off `apps/<namespace>/kustomization.yaml`.
    When that file does not list `<name>`, this step is complete.

The redirect in `httproute.yaml` uses port `8443`.
Gateway `playground` stays in `apps/app-sandbox/sandbox-podinfo/gateway.yaml`.
Both HTTPRoutes stay in `httproute.yaml`.

## Sync one workload

`kustomization.yaml` lists the Kubernetes objects.
`ks.yaml` is the Flux Kustomization for that directory.
`flux reconcile kustomization <name>` targets that directory.

When `<namespace>` is `app-sandbox`, do these steps.
1. Copy `apps/app-sandbox/valkey/ks.yaml` to `apps/app-sandbox/<name>/ks.yaml`.
   When the new file exists, this step is complete.
2. In that file, set `metadata.name` to `<name>`.
   When that name is `<name>`, this step is complete.
3. In that file, set `spec.path` to `./apps/app-sandbox/<name>`.
   When that path is `./apps/app-sandbox/<name>`, this step is complete.
4. Add `- <namespace>/<name>/ks.yaml` under `resources` in `apps/kustomization.yaml`.
   When that file lists `<namespace>/<name>/ks.yaml`, this step is complete.

When `<namespace>` is `app-bank`, do these steps.
A workload with a hostname also depends on `sandbox-podinfo`, as in `apps/app-bank/bank-frontend/ks.yaml`.
1. Copy `apps/app-bank/bank-userservice/ks.yaml` to `apps/app-bank/bank-<name>/ks.yaml`.
   When the new file exists, this step is complete.
2. In that file, set `metadata.name` to `bank-<name>`.
   When that name is `bank-<name>`, this step is complete.
3. In that file, set `spec.path` to `./apps/app-bank/bank-<name>`.
   When that path is `./apps/app-bank/bank-<name>`, this step is complete.
4. Add `- <namespace>/bank-<name>/ks.yaml` under `resources` in `apps/kustomization.yaml`.
   When that file lists `<namespace>/bank-<name>/ks.yaml`, this step is complete.

## The files to match

These lines are in the files you copied.

- CPU and memory requests and limits are in `apps/app-sandbox/valkey/deployment.yaml`.
- The Cache probe is `valkey-cli ping` in `apps/app-sandbox/valkey/deployment.yaml`.
- The podinfo probe is an HTTP path in `apps/app-sandbox/sandbox-podinfo/deployment.yaml`.
- The non-root `securityContext` is in `apps/app-sandbox/valkey/deployment.yaml`.
- The image line in `apps/app-sandbox/sandbox-podinfo/deployment.yaml` names one version.
- The label `app.kubernetes.io/name` is in `apps/app-sandbox/valkey/deployment.yaml`.

## Logs

After the Push section is complete, run this command.

```bash
kubectl -n <namespace> logs deploy/<name> --tail=50
```

When the command prints log lines, this step is complete.
`make logs` prints Flux, the Gateway, podinfo, the Database, and the Cache.

## Secrets

A Secret file lives in a `secrets` directory.
Any file there is encrypted, except `kustomization.yaml`.
SOPS encrypts the `data` and `stringData` values.
`apps/app-bank/secrets/secrets-a.yaml` belongs to namespace `app-bank`.
`apps/app-bank/bank-frontend/secrets/secrets-b.yaml` belongs to that workload.
`make sync` encrypts a new file with SOPS and age.

When `make sync` exits 0, Flux can decrypt that file.

## Push

1. Do the steps in [Push a change](push-a-change.md).

When `make sync` exits 0, this page is complete.
