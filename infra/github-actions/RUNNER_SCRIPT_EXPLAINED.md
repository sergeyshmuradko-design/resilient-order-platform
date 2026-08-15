# Runner Script Explained

This document explains the two local runner scripts line by line. The scripts
are executed by Bash from Makefile targets:

```bash
make github-runner-start
make github-runner-cleanup
```

## start-codespaces-runner.sh

```bash
#!/usr/bin/env bash
```

Tells the operating system to run this file with `bash` found through `env`.
This is more portable than hardcoding `/bin/bash`.

```bash
set -euo pipefail
```

Turns on strict Bash behavior:

- `-e`: stop on the first failed command;
- `-u`: fail when using an unset variable;
- `-o pipefail`: if one command in a pipeline fails, the whole pipeline fails.

```bash
workspace_dir="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

Finds the root directory of the current Git checkout. If the command is not
running inside Git for some reason, falls back to the current directory.

```bash
repo="${GITHUB_REPOSITORY:-}"
```

Reads `GITHUB_REPOSITORY` from the environment. If it is not set, uses an empty
string. Expected format is `OWNER/REPOSITORY`.

```bash
if [ -z "${repo}" ] && command -v gh >/dev/null 2>&1; then
```

If `repo` is empty and `gh` exists in `PATH`, try to infer the repository from
GitHub CLI.

```bash
repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
```

Runs `gh repo view` in the current Git repository, asks for JSON field
`nameWithOwner`, extracts it with `--jq`, and suppresses error output. `|| true`
prevents strict mode from stopping the script if inference fails.

```bash
fi
```

Ends the `if` block.

```bash
if [ -z "${repo}" ]; then
```

If GitHub CLI could not detect the repository, try a Git-only fallback.

```bash
origin_url="$(git -C "${workspace_dir}" remote get-url origin 2>/dev/null || true)"
```

Reads the `origin` remote URL from the workspace repository. `-C` tells Git to
run as if it started in `workspace_dir`.

```bash
repo="$(printf '%s\n' "${origin_url}" \
  | sed -nE 's#^(git@github.com:|https://github.com/)([^/.]+/[^/.]+)(\.git)?$#\2#p')"
```

Converts a GitHub remote URL like
`https://github.com/owner/repo.git` or `git@github.com:owner/repo.git` into the
`owner/repo` format required by the GitHub Actions runner.

```bash
fi
```

Ends the Git remote fallback.

```bash
if [ -z "${repo}" ]; then
```

Checks again whether the repository name is still missing.

```bash
echo "Set GITHUB_REPOSITORY=OWNER/REPOSITORY before starting the runner." >&2
```

Prints an error message to stderr.

```bash
exit 1
```

Stops the script with a non-zero exit code.

```bash
fi
```

Ends the validation block.

```bash
runner_dir="${RUNNER_DIR:-${PWD}/.local/github-runner}"
```

Sets where the GitHub runner binary will be downloaded. Defaults to
`.local/github-runner` under the current project directory. `.local/` is ignored
by Git.

```bash
runner_name="${RUNNER_NAME:-codespaces-${CODESPACE_NAME:-local}}"
```

Sets the visible runner name in GitHub. If Codespaces exposes `CODESPACE_NAME`,
the name includes it; otherwise it uses `codespaces-local`.

```bash
runner_labels="${RUNNER_LABELS:-codespaces,k3d,resilient-orders}"
```

Sets custom labels. The workflow uses these labels in `runs-on`, so GitHub sends
the job to this runner and not to some unrelated self-hosted runner.

```bash
runner_ephemeral="${RUNNER_EPHEMERAL:-true}"
```

Controls whether the runner unregisters itself after one job. Default is
ephemeral, which is safer for a temporary Codespaces setup.

```bash
runner_version="${RUNNER_VERSION:-2.334.0}"
```

Pins the GitHub Actions Runner version by default. This avoids a startup-time
call to GitHub Releases API and keeps local bootstrap behavior reproducible.

```bash
export RUNNER_DIR="${runner_dir}"
export RUNNER_VERSION="${runner_version}"
```

Exports the resolved runner directory and version to workflow jobs. The
bootstrap workflow uses `RUNNER_DIR` to place a destroy-success marker outside
the checkout, and the prune helper uses both values to remove old runner data.

```bash
export TF_VAR_local_env_file="${TF_VAR_local_env_file:-${workspace_dir}/.env}"
```

Exports the Terraform variable used by the platform layer to find the local
`.env` file. The workflow checkout does not contain `.env`, so the runner
process passes the real Codespaces workspace path to Terraform.

```bash
echo "Repository: ${repo}"
echo "Runner version: ${runner_version}"
echo "Terraform local env file: ${TF_VAR_local_env_file}"
```

Prints the important non-secret runtime settings before registration. This
makes troubleshooting easier when the workflow runs in a separate checkout
directory.

```bash
token="${RUNNER_TOKEN:-}"
```

Reads a manually provided GitHub runner registration token if you exported one.

```bash
if [ -z "${token}" ] && command -v gh >/dev/null 2>&1; then
```

If no token was provided and `gh` is available, ask GitHub for a fresh token.

```bash
token="$(gh api -X POST "repos/${repo}/actions/runners/registration-token" --jq .token)"
```

Calls the GitHub REST API through `gh`. This requires your `gh` session to have
permission to manage repository runners. The token is short-lived.

```bash
fi
```

Ends token auto-discovery.

```bash
if [ -z "${token}" ]; then
```

Checks whether token discovery failed.

```bash
echo "Set RUNNER_TOKEN or authenticate gh with access to ${repo}." >&2
```

Explains how to fix the missing token.

```bash
exit 1
```

Stops because runner registration cannot happen without a token.

```bash
fi
```

Ends token validation.

```bash
mkdir -p "${runner_dir}"
```

Creates the runner directory if it does not exist.

```bash
cd "${runner_dir}"
```

Moves into the runner directory. All downloaded runner files live there.

```bash
if [ ! -x ./config.sh ]; then
```

If `config.sh` does not exist or is not executable, the runner package has not
been downloaded/extracted yet.

```bash
archive="actions-runner-linux-x64-${runner_version}.tar.gz"
```

Builds the archive filename for Linux x64.

```bash
curl -fsSLO "https://github.com/actions/runner/releases/download/v${runner_version}/${archive}"
```

Downloads the runner archive. Flags mean:

- `-f`: fail on HTTP errors;
- `-sS`: quiet mode but still show errors;
- `-L`: follow redirects;
- `-O`: save using the remote filename.

```bash
tar xzf "${archive}"
```

Extracts the `.tar.gz` archive into the runner directory.

```bash
fi
```

Ends the download/extract block.

```bash
args=(
```

Starts a Bash array. Arrays avoid fragile string concatenation for command
arguments.

```bash
--unattended
```

Configures the runner without interactive prompts.

```bash
--replace
```

Allows replacing an existing runner with the same name.

```bash
--url "https://github.com/${repo}"
```

Tells the runner which repository it belongs to.

```bash
--token "${token}"
```

Passes the short-lived registration token.

```bash
--name "${runner_name}"
```

Sets the name shown in GitHub runner settings.

```bash
--labels "${runner_labels}"
```

Assigns custom labels used by workflow `runs-on`.

```bash
--work "_work"
```

Sets the job working directory under the runner folder.

```bash
)
```

Ends the Bash array.

```bash
if [ "${runner_ephemeral}" = "true" ]; then
```

Checks whether this runner should process only one job.

```bash
args+=(--ephemeral)
```

Adds the `--ephemeral` option to the existing argument array.

```bash
fi
```

Ends the ephemeral block.

```bash
./config.sh "${args[@]}"
```

Runs GitHub's official runner configuration script with all arguments. This
registers the runner in GitHub.

```bash
./run.sh
```

Starts the runner process. This terminal stays occupied while the runner listens
for jobs and executes them.

```bash
if [ -f "${runner_dir}/.destroy-succeeded" ]; then
  bash "${workspace_dir}/infra/github-actions/prune-codespaces-runner.sh"
fi
```

Runs after the GitHub Actions job has fully exited. If the bootstrap workflow
successfully destroyed the local cluster, it creates `.destroy-succeeded`; this
block then prunes local runner working data without deleting `_work` during
workflow post-steps.

## cleanup-codespaces-runner.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
```

Same as in the start script: run with Bash and fail fast.

```bash
repo="${GITHUB_REPOSITORY:-}"
```

Reads the repository name from the environment.

```bash
if [ -z "${repo}" ] && command -v gh >/dev/null 2>&1; then
  repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
fi
```

If the repository name was not exported, tries to infer it via GitHub CLI.

```bash
runner_dir="${RUNNER_DIR:-${PWD}/.local/github-runner}"
```

Uses the same runner directory as the start script.

```bash
if [ ! -x "${runner_dir}/config.sh" ]; then
```

Checks whether the runner was ever configured locally.

```bash
echo "Runner is not configured at ${runner_dir}."
exit 0
```

If no local runner config exists, cleanup is already done.

```bash
fi
```

Ends the check.

```bash
token="${RUNNER_REMOVE_TOKEN:-}"
```

Reads an optional runner removal token.

```bash
if [ -z "${token}" ] && [ -n "${repo}" ] && command -v gh >/dev/null 2>&1; then
```

If no removal token was exported, but repository and `gh` are available, request
a token from GitHub.

```bash
token="$(gh api -X POST "repos/${repo}/actions/runners/remove-token" --jq .token)"
```

Calls GitHub API to get a short-lived removal token.

```bash
fi
```

Ends token discovery.

```bash
if [ -z "${token}" ]; then
  echo "Set RUNNER_REMOVE_TOKEN or authenticate gh with access to ${repo}." >&2
  exit 1
fi
```

Fails with a clear message if the script still has no removal token.

```bash
cd "${runner_dir}"
```

Moves into the runner directory.

```bash
./config.sh remove --token "${token}"
```

Runs the official GitHub runner cleanup command. It unregisters this local
runner from the GitHub repository.
