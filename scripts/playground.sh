#!/bin/bash
# container 1.7 ships the Cluster command as "container cluster".
# git.localhost is 127.0.0.1 on the Mac and the Git server Service inside the Cluster.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

git_host=git.localhost:18080

section_name=Playground
section_color=37

section() {
  section_name=$1
  case "$1" in
    Cluster) section_color=36 ;;
    Git) section_color=33 ;;
    Flux) section_color=34 ;;
    Platform) section_color=35 ;;
    Secrets) section_color=93 ;;
    Encrypt) section_color=93 ;;
    Decrypt) section_color=94 ;;
    Apps) section_color=32 ;;
    Bank) section_color=92 ;;
    Gateway) section_color=96 ;;
  esac
}

say() {
  if [[ -t 1 ]]; then
    printf '\033[1;%sm==> %-8s\033[0m %s\n' "$section_color" "$section_name" "$*"
  else
    printf '==> %-8s %s\n' "$section_name" "$*"
  fi
}

context() {
  kubectl config use-context playground >/dev/null
}

write_sops_config() {
  local pub
  pub=$(awk '/public key:/{print $NF; exit}' "$root/.local/age.key")
  cat >"$root/.sops.yaml" <<EOF
creation_rules:
  - path_regex: (^|/)secrets/.+
    encrypted_regex: ^(data|stringData)$
    age: ${pub}
EOF
}

require_age_key() {
  local tool
  for tool in sops age; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "brew install $tool" >&2
      exit 1
    fi
  done
  if [[ ! -s $root/.local/age.key ]]; then
    echo ".local/age.key is missing. Run make secrets." >&2
    exit 1
  fi
}

show_secret() {
  local rel=${1#"$root/"}
  if [[ $secret_action == skipped ]]; then
    if [[ $2 == encrypt ]]; then
      say "$rel is already encrypted"
    else
      say "$rel is already plain text"
    fi
    return 0
  fi
  say "$rel"
}

ensure_age() {
  umask 077
  mkdir -p .local
  if [[ ! -s .local/age.key ]]; then
    age-keygen -o .local/age.key >/dev/null 2>&1
  fi
  chmod 600 .local/age.key
  write_sops_config
}

each_secret_file() {
  local dir file
  while IFS= read -r -d '' dir; do
    while IFS= read -r -d '' file; do
      case "$(basename "$file")" in
        kustomization.yaml|kustomization.yml) continue ;;
      esac
      printf '%s\0' "$file"
    done < <(find "$dir" -type f -print0)
  done < <(find "$root/apps" -type d -name secrets -print0)
}

check_secret_file() {
  local file=$1 rel base
  if [[ $file != /* ]]; then
    file=$root/$file
  fi
  if [[ ! -f $file ]]; then
    echo "no file $file" >&2
    exit 1
  fi
  rel=${file#"$root/"}
  base=$(basename "$file")
  case $rel in
    */secrets/*) ;;
    *)
      echo "$rel is outside a secrets directory" >&2
      exit 1
      ;;
  esac
  case $base in
    kustomization.yaml|kustomization.yml)
      echo "$base stays plain text" >&2
      exit 1
      ;;
  esac
  printf '%s' "$file"
}

encrypt_one() {
  local file=$1 rel
  secret_action=skipped
  if grep -q '^sops:' "$file"; then
    return 0
  fi
  rel=${file#"$root/"}
  SOPS_AGE_KEY_FILE="$root/.local/age.key" \
    sops --encrypt --filename-override "$rel" --in-place "$file"
  secret_action=encrypted
}

decrypt_one() {
  local file=$1
  secret_action=skipped
  if ! grep -q '^sops:' "$file"; then
    return 0
  fi
  SOPS_AGE_KEY_FILE="$root/.local/age.key" \
    sops --decrypt --in-place "$file"
  secret_action=decrypted
}

encrypt_secrets() {
  local target=${1:-} file count=0
  section Encrypt
  require_age_key
  write_sops_config
  if [[ -n $target ]]; then
    target=$(check_secret_file "$target") || exit 1
    encrypt_one "$target"
    show_secret "$target" encrypt
    return 0
  fi
  while IFS= read -r -d '' file; do
    count=$((count + 1))
    encrypt_one "$file"
    show_secret "$file" encrypt
  done < <(each_secret_file)
  if [[ $count -eq 0 ]]; then
    say "no secret files"
  fi
}

decrypt_secrets() {
  local target=${1:-} file count=0
  section Decrypt
  require_age_key
  if [[ -n $target ]]; then
    target=$(check_secret_file "$target") || exit 1
    decrypt_one "$target"
    show_secret "$target" decrypt
    return 0
  fi
  while IFS= read -r -d '' file; do
    count=$((count + 1))
    decrypt_one "$file"
    show_secret "$file" decrypt
  done < <(each_secret_file)
  if [[ $count -eq 0 ]]; then
    say "no secret files"
  fi
}

prepare_secrets() {
  umask 077
  mkdir -p .local
  if [[ ! -s .local/postgres-password ]]; then
    openssl rand -base64 24 | tr -d '\n' >.local/postgres-password
  fi
  if [[ ! -s .local/accounts-password ]]; then
    openssl rand -hex 24 | tr -d '\n' >.local/accounts-password
  fi
  if [[ ! -s .local/ledger-password ]]; then
    openssl rand -hex 24 | tr -d '\n' >.local/ledger-password
  fi
  if [[ ! -s .local/jwt.key || ! -s .local/jwt.pub ]]; then
    openssl genrsa -out .local/jwt.key 2048
    openssl rsa -in .local/jwt.key -pubout -out .local/jwt.pub
  fi
  chmod 600 .local/postgres-password .local/accounts-password .local/ledger-password .local/jwt.key .local/jwt.pub
  ensure_age
  python3 - <<'PY'
from pathlib import Path
root = Path(".").resolve()

def write_secret(path, name, secret_type, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text().startswith("sops:") or (path.exists() and "\nsops:\n" in "\n" + path.read_text()):
        return
    lines = ["apiVersion: v1", "kind: Secret", "metadata:", f"  name: {name}"]
    if secret_type:
        lines.append(f"type: {secret_type}")
    lines.append("stringData:")
    for key, value in data.items():
        if "\n" in value:
            lines.append(f"  {key}: |")
            lines.extend(f"    {line}" for line in value.splitlines())
        else:
            escaped = value.replace("\\", "\\\\").replace('"', '\\"')
            lines.append(f'  {key}: "{escaped}"')
    path.write_text("\n".join(lines) + "\n")

def text(path):
    return Path(path).read_text().strip()

postgres = text(".local/postgres-password")
accounts = text(".local/accounts-password")
ledger = text(".local/ledger-password")
write_secret(
    root / "apps/app-sandbox/postgres/secrets/secrets-postgres-auth.yaml",
    "postgres-auth",
    "kubernetes.io/basic-auth",
    {"username": "playground", "password": postgres},
)
write_secret(
    root / "apps/app-bank/secrets/secrets-accounts-auth.yaml",
    "accounts-auth",
    "kubernetes.io/basic-auth",
    {"username": "accounts-admin", "password": accounts},
)
write_secret(
    root / "apps/app-bank/secrets/secrets-ledger-auth.yaml",
    "ledger-auth",
    "kubernetes.io/basic-auth",
    {"username": "admin", "password": ledger},
)
write_secret(
    root / "apps/app-bank/secrets/secrets-accounts-app.yaml",
    "accounts-app",
    "",
    {
        "username": "accounts-admin",
        "password": accounts,
        "dbname": "accounts-db",
        "uri": f"postgresql://accounts-admin:{accounts}@bank-rw.app-bank.svc.cluster.local:5432/accounts-db",
    },
)
write_secret(
    root / "apps/app-bank/secrets/secrets-jwt-key.yaml",
    "jwt-key",
    "",
    {
        "jwtRS256.key": Path(".local/jwt.key").read_text(),
        "jwtRS256.key.pub": Path(".local/jwt.pub").read_text(),
    },
)

for secrets_dir in root.joinpath("apps").rglob("secrets"):
    if not secrets_dir.is_dir():
        continue
    skip = {"kustomization.yaml", "kustomization.yml"}
    files = sorted(
        p.relative_to(secrets_dir).as_posix()
        for p in secrets_dir.rglob("*")
        if p.is_file() and p.name not in skip and p.suffix in {".yaml", ".yml", ".json"}
    )
    if not files:
        continue
    lines = [
        "apiVersion: kustomize.config.k8s.io/v1beta1",
        "kind: Kustomization",
        "resources:",
    ]
    lines.extend(f"  - {name}" for name in files)
    (secrets_dir / "kustomization.yaml").write_text("\n".join(lines) + "\n")
    parent = secrets_dir.parent / "kustomization.yaml"
    text_parent = parent.read_text()
    if "\n  - secrets\n" not in text_parent and not text_parent.endswith("\n  - secrets\n"):
        if "resources:" not in text_parent:
            raise SystemExit(f"{parent} has no resources list")
        parent.write_text(text_parent.replace("resources:\n", "resources:\n  - secrets\n", 1))
PY
  encrypt_secrets
}

commit_secrets() {
  git add -- .sops.yaml
  local file
  while IFS= read -r -d '' file; do
    git add -- "$file"
  done < <(find apps -type f -path '*/secrets/*' -print0)
  if git diff --cached --quiet; then
    return 0
  fi
  git commit -m "$(cat <<'EOF'
Encrypt Playground secrets for this Mac.

EOF
)"
}

install_sops_key() {
  kubectl -n flux-system create secret generic sops-age \
    --from-file=age.agekey=.local/age.key \
    --dry-run=client -o yaml | kubectl apply -f -
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
  say "Adding the container k8s command"
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
  case "$local_port" in
    18080) say "Publishing the Git server at http://${git_host}" ;;
    8443) say "Publishing the Gateway at https://podinfo.localhost:8443" ;;
  esac
  nohup bash -c 'while true; do kubectl -n "$1" port-forward "svc/$2" "$3:$4" --address 127.0.0.1 --address ::1; sleep 1; done' \
    bash "$ns" "$svc" "$local_port" "$remote_port" \
    >".local/${name}-port-forward.log" 2>&1 </dev/null &
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
      pkill -P "$pid" 2>/dev/null || true
      kill "$pid" 2>/dev/null || true
      rm -f "$pidfile"
    fi
  done
  pkill -f "port-forward svc/git-server 18080:18080" >/dev/null 2>&1 || true
  pkill -f "port-forward svc/.* 8443:443" >/dev/null 2>&1 || true
}

patch_dns() {
  local before
  before=$(kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}')
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
  local after
  after=$(kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}')
  if [[ "$before" == "$after" ]]; then
    return 0
  fi
  say "Pointing git.localhost at the Git server inside the Cluster"
  kubectl -n kube-system rollout restart deployment/coredns >/dev/null
  kubectl -n kube-system rollout status deployment/coredns --timeout=120s
}

push_head() {
  local pass url
  say "Pushing main to the Git server"
  start_forward git git-server git-server 18080 18080
  pass=$(cat .local/git-password)
  url="http://learner:${pass}@${git_host}/learner/playground.git"
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
  section Cluster
  say "Starting the container system"
  container system start
  install_shim
  if ! container k8s list | awk 'NR>1 && $1=="playground" { found=1 } END { exit !found }'; then
    say "Creating Cluster playground with 4 CPUs and 8 GB"
    container k8s create --name playground --cpus 4 --memory 8G
  else
    say "Cluster playground is already running"
  fi
  context
  say "Waiting for the node"
  kubectl wait --for=condition=Ready node/playground --timeout=180s
  say "Installing local-path storage"
  kubectl apply -k bootstrap/local-path
  kubectl -n local-path-storage rollout status deployment/local-path-provisioner --timeout=180s
}

git_server() {
  section Git
  say "Installing the Git server"
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
  say "Waiting for the Git server"
  kubectl -n git-server rollout status deployment/git-server --timeout=300s
  patch_dns
  start_forward git git-server git-server 18080 18080
  local pass code
  pass=$(cat .local/git-password)
  if ! kubectl -n git-server exec deploy/git-server -- gitea admin user list | grep -q learner; then
    say "Creating the learner account on the Git server"
    kubectl -n git-server exec deploy/git-server -- \
      gitea admin user create --admin --username learner --password "$pass" \
      --email learner@localhost --must-change-password=false
  fi
  say "Ensuring the playground repository exists"
  code=$(curl -s -o .local/git-repo-response -w '%{http_code}' \
    -u "learner:${pass}" \
    -H 'Content-Type: application/json' \
    -d '{"name":"playground","private":false,"auto_init":false,"default_branch":"main"}' \
    "http://${git_host}/api/v1/user/repos" || true)
  if [[ "$code" != "201" && "$code" != "409" ]]; then
    echo "git repo create failed: HTTP ${code}" >&2
    cat .local/git-repo-response >&2
    return 1
  fi
  push_head
}

bootstrap_flux() {
  local pass=$1 attempt
  for attempt in 1 2 3; do
    if GIT_PASSWORD="$pass" flux bootstrap git \
      --url="http://${git_host}/learner/playground.git" \
      --username=learner \
      --token-auth \
      --allow-insecure-http \
      --silent \
      --branch=main \
      --path=clusters/playground; then
      return 0
    fi
    if [[ "$attempt" == "3" ]]; then
      return 1
    fi
    say "Flux is still reconciling. Retry ${attempt} of 3."
    sleep 15
  done
}

flux_bootstrap() {
  section Flux
  say "Pointing Flux at the Git server"
  context
  push_head
  local pass
  pass=$(cat .local/git-password)
  bootstrap_flux "$pass"
  say "Pointing Flux at the Git server again to confirm nothing changes"
  bootstrap_flux "$pass"
  say "Updating the local checkout from the Git server"
  git fetch playground main
  git merge --ff-only FETCH_HEAD
}

platform() {
  section Platform
  say "Installing cert-manager, Envoy Gateway, and CloudNativePG"
  context
  push_head
  flux reconcile kustomization infrastructure --with-source --timeout=12m
  kubectl -n flux-system wait helmrelease/cert-manager helmrelease/envoy-gateway helmrelease/cloudnative-pg --for=condition=Ready --timeout=2m
  say "Applying the CA and the GatewayClass"
  kubectl apply -f infrastructure/cert-manager/issuer.yaml
  kubectl apply -f infrastructure/envoy-gateway/gatewayclass.yaml
  kubectl wait clusterissuer/playground-root --for=condition=Ready --timeout=3m
  kubectl -n cert-manager wait certificate/playground-ca --for=condition=Ready --timeout=3m
  kubectl wait clusterissuer/playground --for=condition=Ready --timeout=3m
}

apps() {
  section Apps
  say "Installing podinfo, the Cache, and the Database"
  context
  umask 077
  mkdir -p .local
  if [[ ! -s .local/postgres-password ]]; then
    openssl rand -base64 24 | tr -d '\n' >.local/postgres-password
  fi
  prepare_secrets
  commit_secrets
  install_sops_key
  release_replaced
  push_head
  flux reconcile kustomization flux-system --with-source --timeout=5m
  reconcile_workloads
  reconcile_sandbox
  say "Waiting for podinfo, the Cache, and the Database"
  kubectl -n app-sandbox rollout status deployment/podinfo --timeout=180s
  kubectl -n app-sandbox rollout status deployment/valkey --timeout=180s
  kubectl -n app-sandbox wait cluster/postgres --for=condition=Ready --timeout=180s
}

release_replaced() {
  local name
  for name in apps-bank apps app-sandbox postgres valkey sandbox-podinfo app-bank bank-postgres bank-frontend bank-userservice bank-contacts bank-balancereader bank-ledgerwriter bank-transactionhistory; do
    if kubectl -n flux-system get kustomization "$name" >/dev/null 2>&1; then
      kubectl -n flux-system patch kustomization "$name" --type merge \
        -p '{"spec":{"deletionPolicy":"Orphan","prune":false}}'
    fi
  done
}

reconcile_workloads() {
  flux reconcile kustomization workloads --with-source --timeout=2m
}

reconcile_sandbox() {
  flux reconcile kustomization app-sandbox --with-source --timeout=5m
  flux reconcile kustomization postgres --with-source --timeout=10m
  flux reconcile kustomization valkey --with-source --timeout=5m
  flux reconcile kustomization sandbox-podinfo --with-source --timeout=5m
}

reconcile_bank() {
  local name
  flux reconcile kustomization app-bank --with-source --timeout=5m
  flux reconcile kustomization bank-postgres --with-source --timeout=20m
  for name in frontend userservice contacts balancereader ledgerwriter transactionhistory; do
    flux reconcile kustomization "bank-${name}" --with-source --timeout=5m
  done
}

sync_all() {
  context
  local before
  before=$(git rev-parse HEAD)
  prepare_secrets
  commit_secrets
  install_sops_key
  if [[ $(git rev-parse HEAD) != "$before" ]]; then
    push_head
  fi
  release_replaced
  flux reconcile source git flux-system
  flux reconcile kustomization flux-system --with-source --timeout=5m
  flux reconcile kustomization infrastructure --with-source --timeout=10m
  reconcile_workloads
  reconcile_sandbox
  reconcile_bank
}

bank() {
  section Bank
  say "Installing the bank databases and services"
  context
  umask 077
  mkdir -p .local
  prepare_secrets
  commit_secrets
  install_sops_key
  kubectl create namespace app-bank --dry-run=client -o yaml | kubectl apply -f -
  release_replaced
  push_head
  flux reconcile kustomization flux-system --with-source --timeout=5m
  reconcile_workloads
  reconcile_bank
  say "Waiting for the bank databases"
  kubectl -n app-bank wait cluster/bank --for=condition=Ready --timeout=180s
  kubectl -n app-bank wait job/bank-schema --for=condition=complete --timeout=180s
}

gateway_service() {
  kubectl get svc -A -l gateway.envoyproxy.io/owning-gateway-name=playground \
    -o jsonpath='{.items[0].metadata.namespace}{" "}{.items[0].metadata.name}' 2>/dev/null || true
}

publish() {
  context
  start_forward git git-server git-server 18080 18080
  local found ns svc
  found=$(gateway_service)
  if [[ -n "$found" ]]; then
    ns=${found%% *}
    svc=${found##* }
    start_forward gateway "$ns" "$svc" 8443 443
  fi
}

gateway() {
  section Gateway
  say "Opening https://podinfo.localhost:8443"
  context
  umask 077
  mkdir -p .local
  say "Saving the CA to .local/ca.crt"
  kubectl -n cert-manager get secret playground-ca -o jsonpath='{.data.ca\.crt}' | base64 -d >.local/ca.crt
  chmod 600 .local/ca.crt
  if ! security find-certificate -c playground "$HOME/Library/Keychains/login.keychain-db" >/dev/null 2>&1; then
    say "Trusting the CA in the login keychain. macOS may ask for the password once."
    security add-trusted-cert -r trustRoot \
      -k "$HOME/Library/Keychains/login.keychain-db" \
      .local/ca.crt >/dev/null 2>&1 &
    local trust_pid=$!
    for i in $(seq 1 20); do
      if ! kill -0 "$trust_pid" 2>/dev/null; then
        break
      fi
      sleep 1
    done
    if kill -0 "$trust_pid" 2>/dev/null; then
      kill "$trust_pid" 2>/dev/null || true
    fi
    wait "$trust_pid" || true
  fi
  local ns svc i found
  ns=""
  svc=""
  for i in $(seq 1 60); do
    found=$(gateway_service)
    if [[ -n "$found" ]]; then
      ns=${found%% *}
      svc=${found##* }
      break
    fi
    sleep 2
  done
  [[ -n "$svc" ]]
  start_forward gateway "$ns" "$svc" 8443 443
  say "Waiting for the certificates"
  kubectl -n app-sandbox wait --for=condition=Ready certificate/podinfo certificate/bank --timeout=180s
  say "Checking https://podinfo.localhost:8443"
  local ok=0
  for i in $(seq 1 30); do
    if curl --fail --silent --show-error --cacert .local/ca.crt https://podinfo.localhost:8443 >/dev/null; then
      curl --fail --cacert .local/ca.crt https://podinfo.localhost:8443
      ok=1
      break
    fi
    sleep 2
  done
  if [[ "$ok" -ne 1 ]]; then
    echo "podinfo did not answer on https://podinfo.localhost:8443" >&2
    return 1
  fi
  say "Checking https://bank.localhost:8443"
  for i in $(seq 1 30); do
    if curl --fail --silent --show-error --cacert .local/ca.crt https://bank.localhost:8443 >/dev/null; then
      return 0
    fi
    sleep 2
  done
  echo "the bank did not answer on https://bank.localhost:8443" >&2
  return 1
}

secrets() {
  section Secrets
  say "Creating the age key and .sops.yaml"
  prepare_secrets
}

case "${1:-}" in
  cluster) cluster ;;
  git-server) git_server ;;
  flux) flux_bootstrap ;;
  platform) platform ;;
  apps) apps ;;
  bank) bank ;;
  gateway) gateway ;;
  publish) publish ;;
  stop-forwards) stop_forwards ;;
  secrets) secrets ;;
  encrypt) encrypt_secrets "${2:-}" ;;
  decrypt) decrypt_secrets "${2:-}" ;;
  sync) sync_all ;;
  *)
    echo "usage: $0 cluster|git-server|flux|platform|apps|bank|gateway|publish|stop-forwards|sync|secrets|encrypt|decrypt" >&2
    exit 1
    ;;
esac
