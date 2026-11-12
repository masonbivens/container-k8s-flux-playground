## Learned User Preferences

- Use a Makefile, not a Taskfile. The targets are the interface and cover the full setup.
- Aim the Makefile and manifests at developers. Prefer examples over prose. Add a comment only when a target or manifest cannot carry the point.
- Build a sample environment for local workshops, not a single one-change walkthrough.

## Learned Workspace Facts

- The Cluster is created and deleted only with `container k8s` (name `playground`, 4 CPUs, 8 GB). Kind, k3d, minikube, and Docker Desktop stay out. `container system start` is required before `container k8s` runs.
- One Playground per Mac. Day 1 is `make up`. Day 2 is `make status`, `make sync`, and `make logs`. `make down` deletes the Cluster. The Mac needs `container`, `kubectl`, `flux`, and `git`. A missing tool prints one Homebrew install line and the command exits.
- The Git remote is a Git server inside the Cluster. The Learner pushes to it and Flux pulls from it. Flux does not install that server. There is no GitHub login. Apply `bootstrap/git-server/` with kubectl before Flux bootstrap. Flux Kustomizations cover `./apps` and `./infrastructure`.
- Flux HelmRelease installs cert-manager (CA ClusterIssuer `playground`) and Envoy Gateway. Kustomize installs podinfo, Postgres, and Valkey in namespace `apps`.
- podinfo is served at `https://podinfo.localhost:8443` through Envoy Gateway. cert-manager fills the listener certificate from the Playground CA. HTTP redirects to HTTPS. `make up` trusts that CA in the Mac login keychain. `make status` checks `curl --fail --cacert .local/ca.crt https://podinfo.localhost:8443`.
- Valkey is podinfo's cache and has no volume. Postgres is one Deployment, one Service, and one PVC (database `playground`, user `playground`). No sample app connects to Postgres. The password file is `.local/postgres-password`. Git ignores `.local/`.
- `PROMPT.md` is the build brief. `GLOSSARY.md` defines Learner, Cluster, Playground, Gateway, CA, Cache, Database, Git server, Day 1, and Day 2.
