#!/usr/bin/env bash
set -euo pipefail

# Removes local GitHub Actions runner working data after a successful destroy.
#
# The workflow should not delete its own `_work` directory while GitHub Actions
# post-steps may still need it. The start script runs this helper after
# `run.sh` exits, so the job is already finished and the local Terraform state
# is no longer needed.

runner_dir="${RUNNER_DIR:-${PWD}/.local/github-runner}"
runner_version="${RUNNER_VERSION:-2.334.0}"

if [ ! -d "${runner_dir}" ]; then
  echo "Runner directory does not exist: ${runner_dir}"
  exit 0
fi

echo "Pruning local runner workspace in ${runner_dir}"

rm -rf \
  "${runner_dir}/_diag" \
  "${runner_dir}/_work" \
  "${runner_dir}/_tool" \
  "${runner_dir}/_temp" \
  "${runner_dir}/_update" \
  "${runner_dir}/actions-runner-linux-x64-"*.tar.gz

find "${runner_dir}" -maxdepth 1 -type d \
  \( -name 'bin.*' -o -name 'externals.*' \) \
  ! -name "bin.${runner_version}" \
  ! -name "externals.${runner_version}" \
  -exec rm -rf {} +

if [ -d "${runner_dir}/bin.${runner_version}" ]; then
  ln -sfn "${runner_dir}/bin.${runner_version}" "${runner_dir}/bin"
fi

if [ -d "${runner_dir}/externals.${runner_version}" ]; then
  ln -sfn "${runner_dir}/externals.${runner_version}" "${runner_dir}/externals"
fi

rm -f "${runner_dir}/.destroy-succeeded"

echo "Runner prune completed."
