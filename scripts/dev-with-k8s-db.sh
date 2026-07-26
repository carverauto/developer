#!/usr/bin/env bash
# Run the developer portal locally against the cluster Postgres (CNPG).
#
# Opens a port-forward to developer-portal-pg-rw, loads credentials from the
# same secret the app uses in-cluster, then starts mix phx.server.
#
# Usage:
#   ./scripts/dev-with-k8s-db.sh
#   ./scripts/dev-with-k8s-db.sh mix test
#   LOCAL_PG_PORT=5433 ./scripts/dev-with-k8s-db.sh

set -euo pipefail

NAMESPACE="${NAMESPACE:-serviceradar-developer}"
SVC="${SVC:-developer-portal-pg-rw}"
SECRET="${SECRET:-developer-portal-db-credentials}"
LOCAL_PG_PORT="${LOCAL_PG_PORT:-5432}"
REMOTE_PG_PORT="${REMOTE_PG_PORT:-5432}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required" >&2
  exit 1
fi

if ! kubectl -n "${NAMESPACE}" get svc "${SVC}" >/dev/null 2>&1; then
  echo "Service ${NAMESPACE}/${SVC} not found. Check context: $(kubectl config current-context 2>/dev/null || true)" >&2
  exit 1
fi

export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT="${LOCAL_PG_PORT}"
export PGDATABASE="${PGDATABASE:-developer_portal}"
export PGUSER="${PGUSER:-$(kubectl -n "${NAMESPACE}" get secret "${SECRET}" -o jsonpath='{.data.username}' | base64 -d)}"
export PGPASSWORD="${PGPASSWORD:-$(kubectl -n "${NAMESPACE}" get secret "${SECRET}" -o jsonpath='{.data.password}' | base64 -d)}"

if [[ -z "${PGUSER}" || -z "${PGPASSWORD}" ]]; then
  echo "Could not load DB credentials from secret ${NAMESPACE}/${SECRET}" >&2
  exit 1
fi

cleanup() {
  if [[ -n "${PF_PID:-}" ]] && kill -0 "${PF_PID}" 2>/dev/null; then
    kill "${PF_PID}" 2>/dev/null || true
    wait "${PF_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

echo "Port-forwarding ${NAMESPACE}/svc/${SVC} ${LOCAL_PG_PORT}->${REMOTE_PG_PORT} ..."
kubectl -n "${NAMESPACE}" port-forward "svc/${SVC}" "${LOCAL_PG_PORT}:${REMOTE_PG_PORT}" >/tmp/developer-portal-pg-forward.log 2>&1 &
PF_PID=$!

# Wait until Postgres accepts connections on the local port.
for _ in $(seq 1 40); do
  if ! kill -0 "${PF_PID}" 2>/dev/null; then
    echo "port-forward exited early; see /tmp/developer-portal-pg-forward.log" >&2
    cat /tmp/developer-portal-pg-forward.log >&2 || true
    exit 1
  fi
  if command -v pg_isready >/dev/null 2>&1; then
    if pg_isready -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" >/dev/null 2>&1; then
      break
    fi
  elif (echo >/dev/tcp/"${PGHOST}"/"${PGPORT}") >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

echo "DB ready at ${PGHOST}:${PGPORT}/${PGDATABASE} (user=${PGUSER})"
echo "Note: this is the cluster database (Oban/jobs may write). Prefer staging if you have it."

if [[ $# -eq 0 ]]; then
  set -- mix phx.server
fi

exec "$@"
