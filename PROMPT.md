# Playground build

Read [GLOSSARY.md](GLOSSARY.md) and use those words for those things.

Build one Playground on the Learner's Mac. Day 1 creates it. Day 2 checks it, reconciles it, and shows its logs. The Learner uses a Makefile. Show the work with targets and manifests. A comment earns a place only when no target or manifest can carry the point.

## Done

All of these are true:

- `make status` exits 0, the podinfo certificate is Ready, and the curl below prints podinfo's runtime JSON.
- `make sync` exits 0 and reconciles Flux in this run, so a Git push shows up without waiting for the interval.
- `make logs` exits 0 and prints recent logs for Flux, the Gateway, podinfo, Postgres, and Valkey.
- A second `make up` exits 0 and leaves a single Cluster named `playground`.
- `make down` removes that Cluster, and a later `make up` creates it again.

```bash
curl --fail --cacert .local/ca.crt https://podinfo.localhost:8443
```

`container k8s create` publishes the API server only. It has no flag for an application port. `make up` still makes the curl succeed, and it still makes `git push` from the Mac succeed.

## Order

### 1. Require the tools

The Mac already has `container`, `kubectl`, `flux`, and `git`. When one is missing, print one Homebrew install line for that tool and exit 1.

Done when each missing tool produces that line and a non-zero exit, and a Mac with all four continues.

### 2. Create the Cluster

Four CPUs and 8 GB give Envoy Gateway, cert-manager, Postgres, Valkey, the Git server, and Flux room to run.

```bash
container k8s create --name playground --cpus 4 --memory 8G
```

```bash
container k8s delete --name playground
```

Done when `container k8s list` shows `playground`, and `make down` removes only that Cluster.

### 3. Install the Git server

Apply `bootstrap/git-server/` with kubectl before any Flux command. Flux clones from this server, so bootstrap has to find it already running. Serve Git over HTTP for push and clone.

Done when a push from the Mac is accepted and a pod in the Cluster can clone that same repo.

### 4. Bootstrap Flux

Point Flux at the Git server. The branch is `main`. The path is `clusters/playground`. Use the GitRepository that bootstrap creates.

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./apps
  prune: true
  wait: true
```

Add the same shape for `./infrastructure`. Flux Kustomizations include those two paths.

Done when `flux get kustomizations` shows those Kustomizations Ready, and a second bootstrap changes nothing.

### 5. Install the platform with HelmRelease

| Piece | Namespace | Release owns |
| --- | --- | --- |
| cert-manager | `cert-manager` | a CA ClusterIssuer named `playground` |
| Envoy Gateway | `envoy-gateway-system` | the GatewayClass the chart installs |

The CA signs certificates for this Cluster. The Learner's Mac is the only client that needs to trust it.

Done when both HelmReleases are Ready and the ClusterIssuer exists.

### 6. Install the workloads with Kustomize

All three live in namespace `apps`.

| Workload | Shape | Data | Who connects |
| --- | --- | --- | --- |
| podinfo | one Deployment, one Service | none | the Cache, over the Redis protocol Valkey speaks |
| Valkey | one Deployment, one Service | no volume | podinfo's cache address |
| Postgres | one Deployment, one Service, one PVC | database `playground`, user `playground` | workshops, through the Service |

A restart may empty the Cache. The Database keeps its disk. Pin the image versions you verified. Read the pinned podinfo version for the cache address flag, and point that flag at the Valkey Service.

Write the Postgres password to `.local/postgres-password` with `umask 077`. Git tracks the Secret name and ignores `.local/`.

```bash
umask 077
openssl rand -base64 24 > .local/postgres-password
kubectl -n apps create secret generic postgres-auth \
  --from-file=password=.local/postgres-password \
  --dry-run=client -o yaml | kubectl apply -f -
```

```gitignore
.local/
```

Done when all three workloads are Ready, podinfo's cache address is the Valkey Service, and `git check-ignore .local/postgres-password` prints that path.

### 7. Open the Gateway

The certificate DNS name is `podinfo.localhost`. cert-manager fills the listener Secret from the `playground` ClusterIssuer. An HTTP listener on the same hostname redirects to HTTPS. Publish the Gateway so the Learner's URL is `https://podinfo.localhost:8443`.

Trust the CA in the login keychain. macOS may ask for the password once.

```bash
security add-trusted-cert -r trustRoot \
  -k "$HOME/Library/Keychains/login.keychain-db" \
  .local/ca.crt
```

Done when the curl in **Done** exits 0 and prints podinfo's runtime JSON.

### 8. Add the Day 2 targets

`make status` reports the Cluster, the Flux Kustomizations, the podinfo certificate, and the curl. `make sync` reconciles the Git source and the Kustomizations in this run. `make logs` prints recent logs for Flux, the Gateway, podinfo, Postgres, and Valkey.

```bash
flux reconcile source git flux-system
flux reconcile kustomization apps --with-source
flux reconcile kustomization infrastructure --with-source
```

Done when the three Day 2 bullets in **Done** pass on a Cluster that `make up` has already created.

## Layout

```text
Makefile
GLOSSARY.md
PROMPT.md
bootstrap/git-server/
infrastructure/cert-manager/
infrastructure/envoy-gateway/
apps/podinfo/
apps/postgres/
apps/valkey/
clusters/playground/
.local/
```

## Makefile

The target names are the Learner's interface. Split the recipes if you need to. Keep these names.

```make
.PHONY: up down status sync logs

up: require cluster git-server flux platform apps gateway

down:
	container k8s delete --name playground

status:
	container k8s list
	flux get kustomizations
	kubectl wait -n apps --for=condition=Ready certificate --all --timeout=30s
	curl --fail --cacert .local/ca.crt https://podinfo.localhost:8443

sync:
	flux reconcile source git flux-system
	flux reconcile kustomization apps --with-source
	flux reconcile kustomization infrastructure --with-source

logs:
	flux logs --since=10m
	kubectl logs -l app.kubernetes.io/name=envoy --all-containers --tail=50 -A
	kubectl logs -l app.kubernetes.io/name=podinfo --tail=50 -n apps
	kubectl logs -l app.kubernetes.io/name=postgres --tail=50 -n apps
	kubectl logs -l app.kubernetes.io/name=valkey --tail=50 -n apps
```

`make status` exits 0 only when the Cluster is listed, the Kustomizations are Ready, the podinfo certificate is Ready, and the curl exits 0. Set `app.kubernetes.io/name` on the Gateway, podinfo, Postgres, and Valkey pods so `make logs` selects them.

## Manifest rules

- YAML uses 2-space indent. Makefile recipes use tabs.
- Every workload sets CPU and memory requests and limits.
- Probes call that process's own health path.
- Run as a non-root user when the image allows it.
- English for names, comments, and messages.
