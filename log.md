# Directory Update Log

## 2026-11-13

* **Update**: SOPS and age encrypt `secrets/secrets-*.yaml` at any depth. Each `ks.yaml` decrypts its own directory.

## 2026-11-12

* **Update**: Added OKF v0.2 frontmatter so each concept has a type, a title, and a description.
* **Update**: Showed the missing commands in the Learner runbooks.
* **Creation**: Added [Add a workload](docs/runbooks/add-a-workload.md).
* **Update**: Each bank workload is a directory under `apps/bank/` with its own kustomization.
* **Update**: Bank workloads live in `apps/app-bank/bank-<name>/`. Namespace `app-bank` matches that directory. Each workload has its own Flux Kustomization.
