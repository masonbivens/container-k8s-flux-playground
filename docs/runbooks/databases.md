---
type: "Runbook"
title: "Databases"
description: "The Database and the bank databases in the Playground."
tags: [playground, database]
status: stable
generated: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
verified: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
stale_after: 2027-05-11T00:00:00Z
---

# Databases

Last updated: 2026-11-12

CloudNativePG runs two Postgres clusters.
Each cluster has one instance.
This Cluster has one node, so a second instance stays `Pending`.

## The Database

The Database is cluster `postgres` in namespace `app-sandbox`.

- Database name: `playground`
- User: `playground`
- Service: `postgres`
- Password file: `.local/postgres-password`

The Secret `postgres-auth` is `apps/app-sandbox/postgres/secrets/secrets-postgres-auth.yaml`.
SOPS encrypts that file.
The age private key is `.local/age.key`.

## Encrypt or decrypt

`kustomization.yaml` stays plain text.

1. Run `make encrypt`.

When the command exits 0, every secret file is encrypted.

2. Run `make decrypt`.

When the command exits 0, every secret file is plain text.

One file uses `FILE`.

```bash
make encrypt FILE=apps/app-bank/secrets/secrets-accounts-auth.yaml
make decrypt FILE=apps/app-bank/secrets/secrets-accounts-auth.yaml
```

## The bank databases

The bank databases share cluster `bank` in namespace `app-bank`.

- `accounts-db` belongs to `accounts-admin`. The password file is `.local/accounts-password`.
- `postgresdb` belongs to `admin`. The password file is `.local/ledger-password`.

The Job `bank-schema` loads the tables.

If the tables must load again, run this command.

```bash
kubectl -n app-bank delete job bank-schema
```

Then run `make sync`.
Run this command.

```bash
kubectl -n app-bank get job bank-schema
```

When the Job shows `Complete`, the load is complete.

## Show the clusters

1. Run `kubectl get cluster -A`.

When each cluster shows `Cluster in healthy state`, this step is complete.
`READY` is 1.

## Start cluster bank after a failed init

The status text is `Cluster is unrecoverable and needs manual intervention`.
A failed init leaves that disk in place.

CAUTION: These commands remove the bank database disk.
Cluster `postgres` in namespace `app-sandbox` stays.

1. Run this command.

```bash
git show playground/main:apps/app-bank/bank-postgres/cluster.yaml
```

If the command fails, do the steps in [Push a change](push-a-change.md) for `apps/app-bank/bank-postgres/cluster.yaml`.
Then run the command again.
When the command prints the file, this step is complete.
2. Run `kubectl -n app-bank delete cluster bank`.
3. Run `kubectl -n app-bank delete pvc -l cnpg.io/cluster=bank`.
4. Run `make sync`.

When `kubectl -n app-bank get cluster bank` shows `Cluster in healthy state`, this step is complete.

`apps/app-bank/bank-postgres/serviceaccount.yaml` sets `automountServiceAccountToken: true` on ServiceAccount `bank`.
CloudNativePG uses ServiceAccount `bank` to create cluster `bank`.
`apps/app-bank/bank-postgres/schema-job.yaml` sets `automountServiceAccountToken: false`.
The bank workloads set `automountServiceAccountToken: false`.

## WAL disk

`apps/postgres/cluster.yaml` and `apps/app-bank/bank-postgres/cluster.yaml` set the WAL disk to `1Gi`.
Both files set `max_wal_size` to `512MB`.
`max_wal_size` must stay smaller than the WAL disk.
