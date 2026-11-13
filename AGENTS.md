---
type: "Agent Reference"
title: "Agent reference"
description: "Preferences and facts for agents that work in this repository."
tags: [playground, agents]
status: stable
generated: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
verified: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
stale_after: 2027-05-11T00:00:00Z
---

## Learned User Preferences

- Use a Makefile, not a Taskfile. The targets are the interface and cover the full setup.
- Aim the Makefile and manifests at developers. Prefer examples over prose. Add a comment only when a target or manifest cannot carry the point.
- Build a sample environment for local workshops, not a single one-change walkthrough.
- Speed and a turnkey Day 1 beat extra worker nodes.
- `make up` prints a colored stage line before each long step so the Learner can see which stage is running.
- Put each workload at `apps/<namespace>/<workload>/`. The layout follows the Kubernetes hierarchy on disk: the directory name is the namespace, a workload is a directory inside it, and each file is one kind. Those files can share one directory, and that is hard to manage. `kustomization.yaml` lists the Kubernetes objects. `ks.yaml` in that directory is the Flux Kustomization, so `flux reconcile kustomization <name>` targets that directory. Split manifests by kind. The parent kustomization holds the namespace and does not list workload directories.
- Docs follow the OKF spec. Each page has frontmatter with a type, a title, and a description.

## Learned Workspace Facts

- The Cluster is created and deleted only with `container k8s` (name `playground`, 4 CPUs, 8 GB, one node). Kind, k3d, minikube, and Docker Desktop stay out. `container system start` is required before `container k8s` runs.
- One Playground per Mac. Day 1 is `make up`. Day 2 is `make status`, `make sync`, and `make logs`. `make down` deletes the Cluster. The Mac needs `container`, `kubectl`, `flux`, `git`, `sops`, and `age`. A missing tool prints one Homebrew install line and the command exits.
- The Git remote is a Git server inside the Cluster. The Learner pushes to it and Flux pulls from it. Flux does not install that server. There is no GitHub login. Apply `bootstrap/git-server/` with kubectl before Flux bootstrap. Flux Kustomizations cover `./infrastructure`, `./apps/app-sandbox`, `./apps/app-bank`, and each workload directory under those tenants.
- Flux HelmRelease installs cert-manager (CA ClusterIssuer `playground`), Envoy Gateway, and CloudNativePG. Kustomize installs podinfo, Postgres, and Valkey in namespace `app-sandbox` from `apps/app-sandbox/sandbox-podinfo`, `apps/app-sandbox/valkey`, and `apps/app-sandbox/postgres`. Backup, a metrics stack, and a component-upgrade exercise stay out.
- podinfo is served at `https://podinfo.localhost:8443` through Envoy Gateway `playground` in namespace `app-sandbox` (`apps/app-sandbox/sandbox-podinfo/gateway.yaml`). cert-manager fills the listener certificate from the Playground CA. HTTP redirects to HTTPS. `make up` trusts that CA in the Mac login keychain. `make status` checks `curl --fail --cacert .local/ca.crt https://podinfo.localhost:8443`.
- Valkey is podinfo's cache and has no volume. Postgres is one CloudNativePG Cluster in namespace `app-sandbox` with one instance (database `playground`, user `playground`, Service `postgres`). The bank uses a second CloudNativePG Cluster in namespace `app-bank`; `accounts-db` and `postgresdb` share that one cluster. Production CloudNativePG defaults stay on, and `instances` stays at 1 because this Cluster has one node. Password files stay in `.local/`. Any file under a `secrets` directory is encrypted, except `kustomization.yaml`. The SOPS string rule is `^(data|stringData)$`. The age private key is `.local/age.key`. `make secrets` writes that key and `.sops.yaml`, and `make up` runs that target before the workloads. `make encrypt` and `make decrypt` cover every file under a `secrets` directory. `FILE=` names one file. Encrypt before a commit. Flux decrypts with Secret `sops-age` in `flux-system`. Git ignores `.local/`.
- Bank of Anthos is the tenant `apps/app-bank`, served at `https://bank.localhost:8443`. Bank HTTPRoutes set `parentRef` to Gateway `playground` in namespace `app-sandbox`. The directory name is the namespace. `bank-postgres` holds the cluster files. Each bank workload is `apps/app-bank/bank-<name>/` with its own Flux Kustomization. Leave out the load generator, GKE, Cloud SQL, Anthos Service Mesh, Istio, and Skaffold.
- `PROMPT.md` is the build brief. `GLOSSARY.md` defines Learner, Cluster, Playground, Gateway, CA, Cache, Database, Git server, Day 1, Day 2, and Workload.
- `README.md` is Day 1. Read `docs/runbooks/` for Day 2, the Gateway, a Git push, Postgres, `make down`, or a new workload (`docs/runbooks/add-a-workload.md`).
