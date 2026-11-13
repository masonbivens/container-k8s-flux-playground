#!/bin/bash
# Schema and demo rows are applied here so a failed statement can be run again.
# CloudNativePG runs bootstrap SQL once; a failure there leaves the disk half-initialized.
set -euo pipefail

psql_q() {
  local user=$1 password=$2 db=$3
  shift 3
  PGPASSWORD="$password" psql -X -v ON_ERROR_STOP=1 \
    -h "$PGHOST" -p "${PGPORT:-5432}" -U "$user" -d "$db" "$@"
}

wait_db() {
  local user=$1 password=$2 db=$3
  for _ in $(seq 1 60); do
    if psql_q "$user" "$password" "$db" -tAc 'SELECT 1' 2>/dev/null | grep -q 1; then
      return 0
    fi
    sleep 5
  done
  echo "database ${db} did not accept connections" >&2
  return 1
}

wait_db "$ACCOUNTS_USER" "$ACCOUNTS_PASSWORD" "$ACCOUNTS_DB"
if ! psql_q "$ACCOUNTS_USER" "$ACCOUNTS_PASSWORD" "$ACCOUNTS_DB" -tAc "SELECT to_regclass('public.users')" | grep -q users; then
  psql_q "$ACCOUNTS_USER" "$ACCOUNTS_PASSWORD" "$ACCOUNTS_DB" -f /scripts/accounts-schema.sql
fi
count=$(psql_q "$ACCOUNTS_USER" "$ACCOUNTS_PASSWORD" "$ACCOUNTS_DB" -tAc 'SELECT count(*) FROM users')
count=${count//[[:space:]]/}
count=${count:-0}
if [[ "$count" -lt 4 ]]; then
  psql_q "$ACCOUNTS_USER" "$ACCOUNTS_PASSWORD" "$ACCOUNTS_DB" -f /scripts/accounts-seed.sql
fi

wait_db "$LEDGER_USER" "$LEDGER_PASSWORD" "$LEDGER_DB"
if ! psql_q "$LEDGER_USER" "$LEDGER_PASSWORD" "$LEDGER_DB" -tAc "SELECT to_regclass('public.transactions')" | grep -q transactions; then
  psql_q "$LEDGER_USER" "$LEDGER_PASSWORD" "$LEDGER_DB" -f /scripts/ledger-schema.sql
fi
count=$(psql_q "$LEDGER_USER" "$LEDGER_PASSWORD" "$LEDGER_DB" -tAc 'SELECT count(*) FROM transactions')
count=${count//[[:space:]]/}
count=${count:-0}
if [[ "$count" == "0" ]]; then
  export POSTGRES_DB="$LEDGER_DB"
  export POSTGRES_USER="$LEDGER_USER"
  export POSTGRES_PASSWORD="$LEDGER_PASSWORD"
  export USE_DEMO_DATA=True
  bash /scripts/ledger-seed.sh
fi
