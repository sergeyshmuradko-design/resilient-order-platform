#!/usr/bin/env bash
set -euo pipefail

# Starts a GitHub Actions self-hosted runner inside Codespaces.
#
# Nothing is executed when the runner starts. It only connects to GitHub and
# waits for a workflow job whose `runs-on` labels match this runner.

workspace_dir="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

repo="${GITHUB_REPOSITORY:-}"
if [ -z "${repo}" ] && command -v gh >/dev/null 2>&1; then
  repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
fi
if [ -z "${repo}" ]; then
  origin_url="$(git -C "${workspace_dir}" remote get-url origin 2>/dev/null || true)"
  repo="$(printf '%s\n' "${origin_url}" \
    | sed -nE 's#^(git@github.com:|https://github.com/)([^/.]+/[^/.]+)(\.git)?$#\2#p')"
fi

if [ -z "${repo}" ]; then
  echo "Set GITHUB_REPOSITORY=OWNER/REPOSITORY before starting the runner." >&2
  exit 1
fi

runner_dir="${RUNNER_DIR:-${PWD}/.local/github-runner}"
runner_name="${RUNNER_NAME:-codespaces-${CODESPACE_NAME:-local}}"
runner_labels="${RUNNER_LABELS:-codespaces,k3d,resilient-orders}"
runner_ephemeral="${RUNNER_EPHEMERAL:-true}"
runner_version="${RUNNER_VERSION:-2.334.0}"
export RUNNER_DIR="${runner_dir}"
export RUNNER_VERSION="${runner_version}"

# Terraform runs inside the self-hosted runner checkout, where `.env` is not
# committed. Export the local workspace path so Terraform can seed local Vault
# from the developer-only `.env` file during the Codespaces bootstrap.
export TF_VAR_local_env_file="${TF_VAR_local_env_file:-${workspace_dir}/.env}"

echo "Repository: ${repo}"
echo "Runner version: ${runner_version}"
echo "Terraform local env file: ${TF_VAR_local_env_file}"

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

if [ -f "${runner_dir}/.destroy-succeeded" ]; then
  bash "${workspace_dir}/infra/github-actions/prune-codespaces-runner.sh"
fi
