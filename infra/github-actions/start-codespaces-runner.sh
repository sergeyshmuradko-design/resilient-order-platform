#!/usr/bin/env bash
set -euo pipefail

# Starts a GitHub Actions self-hosted runner inside Codespaces.
#
# Nothing is executed when the runner starts. It only connects to GitHub and
# waits for a workflow job whose `runs-on` labels match this runner.

repo="${GITHUB_REPOSITORY:-}"
if [ -z "${repo}" ] && command -v gh >/dev/null 2>&1; then
  repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
fi

if [ -z "${repo}" ]; then
  echo "Set GITHUB_REPOSITORY=OWNER/REPOSITORY before starting the runner." >&2
  exit 1
fi

runner_dir="${RUNNER_DIR:-${PWD}/.local/github-runner}"
runner_name="${RUNNER_NAME:-codespaces-${CODESPACE_NAME:-local}}"
runner_labels="${RUNNER_LABELS:-codespaces,k3d,resilient-orders}"
runner_ephemeral="${RUNNER_EPHEMERAL:-true}"

token="${RUNNER_TOKEN:-}"
if [ -z "${token}" ] && command -v gh >/dev/null 2>&1; then
  token="$(gh api -X POST "repos/${repo}/actions/runners/registration-token" --jq .token)"
fi

if [ -z "${token}" ]; then
  echo "Set RUNNER_TOKEN or authenticate gh with access to ${repo}." >&2
  exit 1
fi

mkdir -p "${runner_dir}"
cd "${runner_dir}"

if [ ! -x ./config.sh ]; then
  runner_version="${RUNNER_VERSION:-}"
  if [ -z "${runner_version}" ]; then
    runner_version="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p' | head -n 1)"
  fi

  archive="actions-runner-linux-x64-${runner_version}.tar.gz"
  curl -fsSLO "https://github.com/actions/runner/releases/download/v${runner_version}/${archive}"
  tar xzf "${archive}"
fi

args=(
  --unattended
  --replace
  --url "https://github.com/${repo}"
  --token "${token}"
  --name "${runner_name}"
  --labels "${runner_labels}"
  --work "_work"
)

if [ "${runner_ephemeral}" = "true" ]; then
  args+=(--ephemeral)
fi

./config.sh "${args[@]}"
./run.sh
