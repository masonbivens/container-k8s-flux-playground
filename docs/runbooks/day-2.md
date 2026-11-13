---
type: "Runbook"
title: "Day 2"
description: "Day 2 is make status, make sync, and make logs on a Playground that already exists."
tags: [playground, day-2]
status: stable
generated: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
verified: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
stale_after: 2027-05-11T00:00:00Z
---

# Day 2

Last updated: 2026-11-12

Day 2 is `make status`, `make sync`, and `make logs` on a Playground that already exists.

## Health

1. Run `make status`.

When the command exits 0, all of these are true:

- `container k8s list` shows `playground`.
- Every Flux kustomization is Ready.
- The certificates `podinfo` and `bank` are Ready.
- The podinfo curl prints the runtime JSON.

```bash
curl --fail --cacert .local/ca.crt https://podinfo.localhost:8443
```

Open the bank with the steps in [Open the apps](open-the-apps.md).

If the curl cannot connect, run `make status` again.
When the curl prints the runtime JSON, this step is complete.
`make status` starts the port forwards for port 18080 and port 8443.

## Sync

1. Run `make sync`.

When the command exits 0, this step is complete.
The command reconciles `flux-system`, `infrastructure`, `workloads`, and each `ks.yaml` in this run.

## Logs

1. Run `make logs`.

When the command prints logs for Flux, the Gateway, podinfo, the Database, and the Cache, this step is complete.

2. Read the bank database logs with this command.

```bash
kubectl -n app-bank logs -l cnpg.io/cluster=bank,cnpg.io/podRole=instance --tail=50
```

When the command prints log lines, this step is complete.

3. Read the frontend logs with this command.

```bash
kubectl -n app-bank logs deploy/frontend --tail=50
```

When the command prints log lines, this step is complete.
