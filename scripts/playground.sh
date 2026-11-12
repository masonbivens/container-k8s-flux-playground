#!/bin/bash
# container 1.7 ships the Cluster command as "container cluster".
# git.localhost is 127.0.0.1 on the Mac and the Git server Service inside the Cluster.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

context() {
  kubectl config use-context playground >/dev/null
}

install_shim() {
  if container k8s list >/dev/null 2>&1; then
    return 0
  fi
  local bin prefix plugin_root cluster_bin dest
  bin=$(readlink -f "$(command -v container)")
  prefix=$(dirname "$(dirname "$bin")")
  plugin_root="$prefix/libexec/container-plugins"
  cluster_bin="$plugin_root/cluster/bin/cluster"
  dest="$plugin_root/k8s"
  if [[ ! -x "$cluster_bin" ]]; then
    echo "container k8s is not available" >&2
    return 1
  fi
  mkdir -p "$dest/bin"
  cp "$plugin_root/cluster/config.toml" "$dest/config.toml"
  cat >"$dest/bin/k8s" <<EOF
#!/bin/sh
exec "$cluster_bin" "\$@"
EOF
  chmod 755 "$dest/bin/k8s"
  container k8s list >/dev/null
}

start_forward() {
  local name=$1 ns=$2 svc=$3 local_port=$4 remote_port=$5
  local pidfile=".local/${name}-port-forward.pid"
  mkdir -p .local
  if [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    if lsof -nP -iTCP:"$local_port" -sTCP:LISTEN >/dev/null 2>&1; then
      return 0
    fi
    kill "$(cat "$pidfile")" 2>/dev/null || true
  fi
  nohup kubectl -n "$ns" port-forward "svc/$svc" "${local_port}:${remote_port}" \
    --address 127.0.0.1 --address ::1 \
    >".local/${name}-port-forward.log" 2>&1 &
  echo $! >"$pidfile"
  local i
  for i in $(seq 1 30); do
    if lsof -nP -iTCP:"$local_port" -sTCP:LISTEN >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "port-forward ${local_port} did not start" >&2
  cat ".local/${name}-port-forward.log" >&2
  return 1
}

stop_forwards() {
  local pidfile pid
  for pidfile in .local/git-port-forward.pid .local/gateway-port-forward.pid; do
    if [[ -f "$pidfile" ]]; then
      pid=$(cat "$pidfile")
      kill "$pid" 2>/dev/null || true
      rm -f "$pidfile"
    fi
  done
  pkill -f "port-forward svc/git-server 8080:8080" >/dev/null 2>&1 || true
  pkill -f "port-forward svc/.* 8443:443" >/dev/null 2>&1 || true
}

patch_dns() {
  kubectl -n kube-system get cm coredns -o json | python3 -c '
import json, sys
cm = json.load(sys.stdin)
core = cm["data"]["Corefile"]
block = """    hosts {
        10.96.200.10 git.localhost
        fallthrough
    }
"""
if "git.localhost" not in core:
    needle = "    prometheus :9153\n"
    if needle not in core:
        sys.exit("Corefile has no prometheus block")
    core = core.replace(needle, block + needle, 1)
    cm["data"]["Corefile"] = core
cm.pop("status", None)
meta = cm.setdefault("metadata", {})
for key in ("resourceVersion", "uid", "creationTimestamp", "managedFields"):
    meta.pop(key, None)
json.dump(cm, sys.stdout)
' | kubectl apply -f -
  kubectl -n kube-system rollout restart deployment/coredns >/dev/null
  kubectl -n kube-system rollout status deployment/coredns --timeout=120s
}

push_head() {
  local pass url
  pass=$(cat .local/git-password)
  url="http://learner:${pass}@git.localhost:8080/learner/playground.git"
  if git remote get-url playground >/dev/null 2>&1; then
    git remote set-url playground "$url"
  else
    git remote add playground "$url"
  fi
  if git ls-remote --heads playground main | grep -q .; then
    git fetch playground main
    git merge --ff-only FETCH_HEAD
  fi
  git push playground HEAD:main
}

cluster() {
  container system start
  install_shim
  if ! container k8s list | awk 'NR>1 && $1=="playground" { found=1 } END { exit !found }'; then
    container k8s create --name playground --cpus 4 --memory 8G
  fi
  context
  kubectl wait --for=condition=Ready node/playground --timeout=180s
  kubectl apply -k bootstrap/local-path
  kubectl -n local-path-storage rollout status deployment/local-path-provisioner --timeout=180s
}

git_server() {
  context
  umask 077
  mkdir -p .local
  if [[ ! -s .local/gitea-secret-key ]]; then
    openssl rand -hex 32 | tr -d '\n' >.local/gitea-secret-key
  fi
  if [[ ! -s .local/gitea-internal-token ]]; then
    openssl rand -hex 32 | tr -d '\n' >.local/gitea-internal-token
  fi
  if [[ ! -s .local/git-password ]]; then
    openssl rand -hex 24 | tr -d '\n' >.local/git-password
  fi
  kubectl apply -f bootstrap/git-server/namespace.yaml
  kubectl -n git-server create secret generic gitea-config \
    --from-file=secret-key=.local/gitea-secret-key \
    --from-file=internal-token=.local/gitea-internal-token \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -k bootstrap/git-server
  kubectl -n git-server rollout status deployment/git-server --timeout=300s
  patch_dns
  start_forward git git-server git-server 8080 8080
  local pass code
  pass=$(cat .local/git-password)
  if ! kubectl -n git-server exec deploy/git-server -- gitea admin user list | grep -q learner; then
    kubectl -n git-server exec deploy/git-server -- \
      gitea admin user create --admin --username learner --password "$pass" \
      --email learner@localhost --must-change-password=false
  fi
  code=$(curl -s -o .local/git-repo-response -w '%{http_code}' \
    -u "learner:${pass}" \
    -H 'Content-Type: application/json' \
    -d '{"name":"playground","private":false,"auto_init":false,"default_branch":"main"}' \
    http://git.localhost:8080/api/v1/user/repos || true)
  if [[ "$code" != "201" && "$code" != "409" ]]; then
    echo "git repo create failed: HTTP ${code}" >&2
    cat .local/git-repo-response >&2
    return 1
  fi
  push_head
}

flux_bootstrap() {
  context
  start_forward git git-server git-server 8080 8080
  push_head
  local pass
  pass=$(cat .local/git-password)
  GIT_PASSWORD="$pass" flux bootstrap git \
    --url=http://git.localhost:8080/learner/playground.git \
    --username=learner \
    --token-auth \
    --allow-insecure-http \
    --silent \
    --branch=main \
    --path=clusters/playground
  GIT_PASSWORD="$pass" flux bootstrap git \
    --url=http://git.localhost:8080/learner/playground.git \
    --username=learner \
    --token-auth \
    --allow-insecure-http \
    --silent \
    --branch=main \
    --path=clusters/playground
  git fetch playground main
  git merge --ff-only FETCH_HEAD
}

platform() {
  context
  push_head
  local i
  for i in 1 2 3 4 5 6; do
    if flux reconcile kustomization infrastructure --with-source --timeout=10m; then
      break
    fi
    if [[ "$i" == "6" ]]; then
      return 1
    fi
    sleep 15
  done
  kubectl -n flux-system wait helmrelease/cert-manager helmrelease/envoy-gateway --for=condition=Ready --timeout=10m
  kubectl apply -f infrastructure/cert-manager/issuer.yaml
  kubectl apply -f infrastructure/envoy-gateway/gatewayclass.yaml
  kubectl wait clusterissuer/playground-root --for=condition=Ready --timeout=3m
  kubectl -n cert-manager wait certificate/playground-ca --for=condition=Ready --timeout=3m
  kubectl wait clusterissuer/playground --for=condition=Ready --timeout=3m
}

apps() {
  context
  umask 077
  mkdir -p .local
  if [[ ! -s .local/postgres-password ]]; then
    openssl rand -base64 24 | tr -d '\n' >.local/postgres-password
  fi
  kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n apps create secret generic postgres-auth \
    --from-file=password=.local/postgres-password \
    --dry-run=client -o yaml | kubectl apply -f -
  push_head
  flux reconcile kustomization apps --with-source --timeout=10m
  kubectl -n apps rollout status deployment/podinfo --timeout=180s
  kubectl -n apps rollout status deployment/valkey --timeout=180s
  kubectl -n apps rollout status deployment/postgres --timeout=180s
}

gateway() {
  context
  umask 077
  mkdir -p .local
  kubectl -n cert-manager get secret playground-ca -o jsonpath='{.data.ca\.crt}' | base64 -d >.local/ca.crt
  chmod 600 .local/ca.crt
  if ! security find-certificate -c playground "$HOME/Library/Keychains/login.keychain-db" >/dev/null 2>&1; then
    security add-trusted-cert -r trustRoot \
      -k "$HOME/Library/Keychains/login.keychain-db" \
      .local/ca.crt || true
  fi
  local svc i
  svc=""
  for i in $(seq 1 60); do
    svc=$(kubectl -n apps get svc -l gateway.envoyproxy.io/owning-gateway-name=playground -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -n "$svc" ]]; then
      break
    fi
    sleep 2
  done
  [[ -n "$svc" ]]
  start_forward gateway apps "$svc" 8443 443
  kubectl -n apps wait --for=condition=Ready certificate/podinfo --timeout=180s
  for i in $(seq 1 30); do
    if curl --fail --silent --show-error --cacert .local/ca.crt https://podinfo.localhost:8443 >/dev/null; then
      curl --fail --cacert .local/ca.crt https://podinfo.localhost:8443
      return 0
    fi
    sleep 2
  done
  echo "podinfo did not answer on https://podinfo.localhost:8443" >&2
  return 1
}

case "${1:-}" in
  cluster) cluster ;;
  git-server) git_server ;;
  flux) flux_bootstrap ;;
  platform) platform ;;
  apps) apps ;;
  gateway) gateway ;;
  stop-forwards) stop_forwards ;;
  *)
    echo "usage: $0 cluster|git-server|flux|platform|apps|gateway|stop-forwards" >&2
    exit 1
    ;;
esac
