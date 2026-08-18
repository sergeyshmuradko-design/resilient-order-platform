#!/usr/bin/env bash
set -euo pipefail

# Unregisters the local Codespaces runner when it was configured as persistent.
# Ephemeral runners normally remove themselves after one job.

repo="${GITHUB_REPOSITORY:-}"
if [ -z "${repo}" ] && command -v gh >/dev/null 2>&1; then
  repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
fi

runner_dir="${RUNNER_DIR:-${PWD}/.local/github-runner}"
runner_version="${RUNNER_VERSION:-2.334.0}"

if [ ! -x "${runner_dir}/config.sh" ]; then
  echo "Runner is not configured at ${runner_dir}."
  exit 0
fi

if [ -d "${runner_dir}/bin.${runner_version}" ] && [ ! -x "${runner_dir}/bin/Runner.Listener" ]; then
  echo "Repairing runner bin symlink for version ${runner_version}"
  ln -sfn "${runner_dir}/bin.${runner_version}" "${runner_dir}/bin"
fi

if [ -d "${runner_dir}/externals.${runner_version}" ] && [ ! -e "${runner_dir}/externals/node20/bin/node" ]; then
  echo "Repairing runner externals symlink for version ${runner_version}"
  ln -sfn "${runner_dir}/externals.${runner_version}" "${runner_dir}/externals"
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
