#!/usr/bin/env bash
set -euo pipefail

# Unregisters the local Codespaces runner when it was configured as persistent.
# Ephemeral runners normally remove themselves after one job.

repo="${GITHUB_REPOSITORY:-}"
if [ -z "${repo}" ] && command -v gh >/dev/null 2>&1; then
  repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
fi

runner_dir="${RUNNER_DIR:-${PWD}/.local/github-runner}"

if [ ! -x "${runner_dir}/config.sh" ]; then
  echo "Runner is not configured at ${runner_dir}."
  exit 0
fi

token="${RUNNER_REMOVE_TOKEN:-}"
if [ -z "${token}" ] && [ -n "${repo}" ] && command -v gh >/dev/null 2>&1; then
  token="$(gh api -X POST "repos/${repo}/actions/runners/remove-token" --jq .token)"
fi

if [ -z "${token}" ]; then
  echo "Set RUNNER_REMOVE_TOKEN or authenticate gh with access to ${repo}." >&2
  exit 1
fi

cd "${runner_dir}"
./config.sh remove --token "${token}"
