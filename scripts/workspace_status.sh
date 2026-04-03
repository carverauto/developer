#!/usr/bin/env bash

set -eo pipefail

remove_url_credentials() {
  which perl >/dev/null && perl -pe 's#//.*?:.*?@#//#' || cat
}

repo_url="$(git config --get remote.origin.url 2>/dev/null | remove_url_credentials || true)"
echo "REPO_URL ${repo_url}"

commit_sha="$(git rev-parse HEAD 2>/dev/null || echo dev)"
echo "COMMIT_SHA ${commit_sha}"

git_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
echo "GIT_BRANCH ${git_branch}"

git_tree_status="$(
  if git rev-parse HEAD >/dev/null 2>&1; then
    git diff-index --quiet HEAD -- && echo "Clean" || echo "Modified"
  else
    echo "Unknown"
  fi
)"
echo "GIT_TREE_STATUS ${git_tree_status}"

if [[ -f VERSION ]]; then
  version="$(tr -d '\n' < VERSION)"
else
  version="dev"
fi

if [[ -n "${version}" && "${version}" != "dev" ]]; then
  if ! git rev-parse HEAD >/dev/null 2>&1 || ! git tag --points-at HEAD | grep -Fxq "v${version}"; then
    version="dev"
  fi
fi

echo "STABLE_VERSION ${version}"
echo "STABLE_COMMIT_SHA ${commit_sha}"

build_id="${BUILD_ID:-}"
if [[ -n "${build_id}" ]]; then
  echo "STABLE_BUILD_ID ${build_id}"
fi

now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
now_compact="$(date -u +"%Y%m%dT%H%M%SZ")"

echo "BUILD_TIMESTAMP ${now}"
echo "BUILD_TIMESTAMP_COMPACT ${now_compact}"
