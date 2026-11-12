SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: up down status sync logs require cluster git-server flux platform apps gateway

up: require cluster git-server flux platform apps gateway

require:
	for tool in container kubectl flux git; do \
		if ! command -v $$tool >/dev/null 2>&1; then \
			case $$tool in \
				container) echo "brew install container" ;; \
				kubectl) echo "brew install kubectl" ;; \
				flux) echo "brew install fluxcd/tap/flux" ;; \
				git) echo "brew install git" ;; \
			esac; \
			exit 1; \
		fi; \
	done

cluster: require
	bash scripts/playground.sh cluster

git-server: cluster
	bash scripts/playground.sh git-server

flux: git-server
	bash scripts/playground.sh flux

platform: flux
	bash scripts/playground.sh platform

apps: platform
	bash scripts/playground.sh apps

gateway: apps
	bash scripts/playground.sh gateway

down:
	bash scripts/playground.sh stop-forwards
	container system start
	container k8s delete --name playground

status:
	kubectl config use-context playground
	container k8s list | awk 'NR>1 && $$1=="playground" { found=1 } END { exit !found }'
	flux get kustomizations
	kubectl -n flux-system wait kustomization --all --for=condition=Ready --timeout=30s
	kubectl wait -n apps --for=condition=Ready certificate --all --timeout=30s
	curl --fail --cacert .local/ca.crt https://podinfo.localhost:8443

sync:
	kubectl config use-context playground
	flux reconcile source git flux-system
	flux reconcile kustomization apps --with-source
	flux reconcile kustomization infrastructure --with-source

logs:
	kubectl config use-context playground
	flux logs --since=10m
	kubectl logs -l app.kubernetes.io/name=envoy --all-containers --tail=50 -A
	kubectl logs -l app.kubernetes.io/name=podinfo --tail=50 -n apps
	kubectl logs -l app.kubernetes.io/name=postgres --tail=50 -n apps
	kubectl logs -l app.kubernetes.io/name=valkey --tail=50 -n apps
