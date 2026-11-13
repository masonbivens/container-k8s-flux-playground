---
type: "Guide"
title: "Playground"
description: "Day 1 creates the Playground on the Learner's Mac."
tags: [playground, day-1]
status: stable
generated: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
verified: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
stale_after: 2027-05-11T00:00:00Z
---

# Playground

Day 1 creates the Playground on your Mac.
[GLOSSARY.md](GLOSSARY.md) defines the names in this repository.
Day 2 is [Day 2](docs/runbooks/day-2.md).

Last updated: 2026-11-13

## The Playground

`make up` creates one Cluster named `playground`.
The Git server is `http://git.localhost:18080/learner/playground.git`.
podinfo answers at `https://podinfo.localhost:8443`.
The bank answers at `https://bank.localhost:8443`.

The directory name is the namespace.
Namespace `app-sandbox` holds podinfo, the Cache, and the Database.
Namespace `app-bank` holds the bank.
A bank workload directory is `apps/app-bank/bank-<name>/`.

```text
apps/app-sandbox/sandbox-podinfo/
apps/app-sandbox/valkey/
apps/app-sandbox/postgres/
apps/app-bank/bank-frontend/
apps/app-bank/bank-postgres/
```

One Mac has one Playground.

## Getting started

The Mac needs `container`, `kubectl`, `flux`, `git`, `sops`, and `age`.

1. Open a shell in this repository.
2. Run `make up`.
3. If `make up` prints one install line, run that line.
4. If you ran that line, run `make up` again.

When `make up` exits 0, Day 1 is complete.

`make up` runs nine stages.
Each stage prints a colored line before the work.
The stages are `require`, `cluster`, `git-server`, `flux`, `platform`, `secrets`, `apps`, `bank`, and `gateway`.
A second `make up` keeps this Cluster.

Git ignores `.local/`.
The age private key and the password files stay in `.local/`.
`.sops.yaml` matches any file under a `secrets` directory, except `kustomization.yaml`.
SOPS encrypts the `data` and `stringData` values in that file.

## Open the pages

1. Do the steps in [Open the apps](docs/runbooks/open-the-apps.md).

When the page accepts that login, this step is complete.

## Runbooks

Read the file that matches the task.

- Health, reconcile, or logs: [Day 2](docs/runbooks/day-2.md)
- podinfo or the bank page: [Open the apps](docs/runbooks/open-the-apps.md)
- A push to the Git server: [Push a change](docs/runbooks/push-a-change.md)
- A new workload: [Add a workload](docs/runbooks/add-a-workload.md)
- Postgres or a failed bank init: [Databases](docs/runbooks/databases.md)
- Remove the Cluster: [Remove the Cluster](docs/runbooks/remove-the-cluster.md)
