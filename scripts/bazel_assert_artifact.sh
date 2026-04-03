#!/usr/bin/env bash

set -euo pipefail

artifact="${1:?artifact path is required}"

if [[ ! -f "${artifact}" ]]; then
  echo "expected artifact missing: ${artifact}" >&2
  exit 1
fi
