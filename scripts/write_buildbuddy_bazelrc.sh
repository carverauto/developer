#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RC_FILE="${REPO_ROOT}/.bazelrc.remote"
REQUIRE_KEY=0

usage() {
  cat <<'EOF'
Usage: write_buildbuddy_bazelrc.sh [--require-key]

Writes .bazelrc.remote with the BuildBuddy API key header expected by this repo.

Environment:
  BUILDBUDDY_API_KEY
  BUILDBUDDY_ORG_API_KEY

The first non-empty variable is used. If neither is set:
  - default: exit successfully without writing anything
  - --require-key: exit with code 1
EOF
}

while (($# > 0)); do
  case "$1" in
    --require-key)
      REQUIRE_KEY=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

KEY="${BUILDBUDDY_API_KEY:-${BUILDBUDDY_ORG_API_KEY:-}}"

if [[ -z "${KEY}" ]]; then
  if [[ "${REQUIRE_KEY}" == "1" ]]; then
    echo "BuildBuddy API key is required. Set BUILDBUDDY_API_KEY or BUILDBUDDY_ORG_API_KEY." >&2
    exit 1
  fi

  echo "No BuildBuddy API key found; leaving ${RC_FILE} unchanged." >&2
  exit 0
fi

OLD_UMASK="$(umask)"
umask 077
printf 'common --remote_header=x-buildbuddy-api-key=%s\n' "${KEY}" > "${RC_FILE}"
umask "${OLD_UMASK}"

echo "Wrote ${RC_FILE}" >&2
