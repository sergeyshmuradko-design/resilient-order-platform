# GitOps Bootstrap Workflow Explained

This document explains `.github/workflows/codespaces-cluster-setup.yml`.

## Quick Reminder

1. Open Codespaces.
2. Make sure the repository has Infisical settings in GitHub Actions:

```text
Repository -> Settings -> Secrets and variables -> Actions
```

Required secrets:

```text
INFISICAL_UNIVERSAL_AUTH_CLIENT_ID
INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET
```

Required variables:

```text
INFISICAL_HOST_API
INFISICAL_PROJECT_SLUG
INFISICAL_ENVIRONMENT_SLUG
INFISICAL_SECRETS_PATH
```

3. Start the self-hosted runner in a dedicated terminal:

```bash
export GITHUB_REPOSITORY="OWNER/REPOSITORY"
make github-runner-start
```

4. Open GitHub:

```text
Repository -> Actions -> Codespaces Cluster Setup -> Run workflow
```

5. First run:

```text
mode = plan
```

This runs `plan` only.

On an empty Codespaces environment, this plans only the `codespaces` layer
because the `platform` layer needs a reachable Kubernetes context.

6. Create/update:

```text
mode = apply
```

This applies `codespaces` first and `platform` second.

7. Return to the pre-cluster state:

```text
mode = destroy
```

This destroys `platform` first and `codespaces` second. The Codespaces destroy
step deletes the local k3d cluster.

## Big Picture

The workflow does not run on GitHub-hosted infrastructure. It runs on your
Codespaces self-hosted runner.

Flow:

1. You start runner locally.
2. GitHub sees a runner with labels `self-hosted`, `codespaces`, `k3d`,
   `resilient-orders`.
3. You manually start the workflow in GitHub UI.
4. GitHub matches the workflow job to your runner labels.
5. The runner executes the workflow steps inside Codespaces.
6. The workflow downloads Terraform for the job.
7. Terraform applies or destroys two layers:
   - `infra/terraform/codespaces`
   - `infra/terraform/platform`

## Line-by-Line Explanation

```yaml
name: Codespaces Cluster Setup
```

Human-readable workflow name in GitHub Actions UI.

```yaml
on:
  workflow_dispatch:
```

The workflow starts only manually from GitHub UI. This is safer for a public
repository because random pushes or pull requests do not run code on your
Codespaces runner.

```yaml
inputs:
```

Defines the form fields shown by `Run workflow`.

```yaml
mode:
  description: "Choose whether to plan, apply or destroy the local Codespaces cluster setup."
  required: true
  type: choice
  default: plan
  options:
    - plan
    - apply
    - destroy
```

Single choice input. `plan` only plans the local k3d layer, `apply` creates or
updates the local cluster and platform layer, and `destroy` removes platform
resources before deleting the local k3d cluster.

```yaml
jobs:
  terraform:
```

Defines one job named `terraform`.

```yaml
runs-on: [self-hosted, codespaces, k3d, resilient-orders]
```

GitHub will run this job only on a self-hosted runner with all these labels.
Those labels must match `RUNNER_LABELS` in
`infra/github-actions/start-codespaces-runner.sh`.

```yaml
env:
  TF_IN_AUTOMATION: "true"
```

Sets Terraform automation mode for all steps. Terraform adjusts output for
CI-like logs. It does not apply changes by itself.

```yaml
steps:
```

Ordered list of actions and shell commands.

```yaml
- name: Checkout repository
  uses: actions/checkout@v4
  with:
    clean: false
```

Downloads the repository into the runner workspace. Without this, Terraform
files are not available to the job. `clean: false` is important for this local
Codespaces setup because Terraform uses local state files. If checkout cleaned
untracked files on every run, a later destroy workflow could lose the state
created by an earlier apply workflow.

In a real cloud setup, use a remote Terraform backend instead of relying on
local state in a self-hosted runner workspace.

```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: 1.10.5
```

Downloads Terraform CLI for this job. Codespaces does not need Terraform
preinstalled.

```yaml
- name: Terraform fmt
  run: terraform -chdir=infra/terraform fmt -check -recursive
```

Checks formatting for all Terraform layers.

```yaml
- name: Codespaces Terraform init
  run: terraform -chdir=infra/terraform/codespaces init
```

Initializes the local k3d cluster layer.

```yaml
- name: Platform Terraform init
  run: terraform -chdir=infra/terraform/platform init
```

Initializes the Kubernetes/Helm platform layer.

```yaml
- name: Codespaces Terraform validate
  run: terraform -chdir=infra/terraform/codespaces validate
```

Validates the local k3d layer syntax.

```yaml
- name: Platform Terraform validate
  run: terraform -chdir=infra/terraform/platform validate
```

Validates the platform layer syntax.

```yaml
- name: Codespaces Terraform plan
  if: ${{ inputs.mode == 'plan' || inputs.mode == 'apply' }}
  run: terraform -chdir=infra/terraform/codespaces plan -out=tfplan
```

Plans k3d cluster creation/reuse for `plan` and `apply` modes.

```yaml
- name: Codespaces Terraform apply
  if: ${{ inputs.mode == 'apply' }}
  run: terraform -chdir=infra/terraform/codespaces apply -auto-approve tfplan
```

Applies the saved k3d plan only in `apply` mode.

```yaml
- name: Platform Terraform plan
  if: ${{ inputs.mode == 'apply' }}
  env:
    TF_VAR_repository_url: ${{ github.server_url }}/${{ github.repository }}.git
    TF_VAR_target_revision: ${{ github.ref_name }}
  run: terraform -chdir=infra/terraform/platform plan -out=tfplan
```

Plans platform resources after the k3d cluster has been applied. This is skipped
in pure `plan` mode because a fresh Codespaces run may not have a reachable
cluster yet. The `TF_VAR_*` environment variables become Terraform variables:

- `repository_url`: Git repo URL for Argo CD;
- `target_revision`: branch/tag for Argo CD.

```yaml
- name: Platform Terraform apply
  if: ${{ inputs.mode == 'apply' }}
  run: terraform -chdir=infra/terraform/platform apply -auto-approve tfplan
```

Applies the saved platform plan after the k3d cluster exists.

The old workflow used an explicit `kubectl delete application` step here. The
current flow does not need it: Terraform manages the GitOps handoff as the
`resilient-orders-bootstrap` Helm release. During destroy, Terraform uninstalls
that bootstrap release before uninstalling Argo CD, so Argo CD can process the
root Application finalizer and prune child Applications while its controller is
still running.

```yaml
- name: Platform Terraform destroy
  if: ${{ inputs.mode == 'destroy' }}
  env:
    TF_VAR_repository_url: ${{ github.server_url }}/${{ github.repository }}.git
    TF_VAR_target_revision: ${{ github.ref_name }}
  run: terraform -chdir=infra/terraform/platform destroy -auto-approve
```

Destroys the platform layer. Terraform removes the bootstrap Helm release first,
then removes Argo CD, operators, namespaces and other platform resources before
the Kubernetes cluster disappears.

```yaml
- name: Codespaces Terraform destroy
  if: ${{ inputs.mode == 'destroy' }}
  run: terraform -chdir=infra/terraform/codespaces destroy -auto-approve
```

Destroys the local Codespaces layer second. Its `terraform_data` destroy
provisioner deletes the k3d cluster.

```yaml
- name: Mark local runner workspace for pruning
  if: ${{ inputs.mode == 'destroy' && success() }}
  run: |
    mkdir -p "$RUNNER_DIR"
    touch "$RUNNER_DIR/.destroy-succeeded"
```

Creates a marker file outside the workflow checkout. The runner start script
sees this marker after `run.sh` exits and then prunes `.local/github-runner`
working data. The workflow itself does not delete `_work` while GitHub Actions
post-steps may still be running.

## Safe Modes

Plan local cluster only:

```text
mode=plan
```

Full platform planning requires a created cluster. Use `mode=apply` for the
first end-to-end bootstrap run.

Create/update:

```text
mode=apply
```

Destroy everything managed by Terraform:

```text
mode=destroy
```

## Common Mistakes

`No runner matching labels`

The runner is not started, or `RUNNER_LABELS` do not match `runs-on`.

`terraform: command not found`

The `Setup Terraform` step failed or was skipped. Check workflow logs.

`k3d: command not found`

The job is running on a machine without k3d. Make sure it runs on the
Codespaces self-hosted runner.

`Error: Kubernetes cluster unreachable`

The platform layer ran before the Codespaces layer created the k3d cluster, or
the kube-context is not available.
