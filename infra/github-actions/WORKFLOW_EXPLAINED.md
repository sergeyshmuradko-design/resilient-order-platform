# GitOps Bootstrap Workflow Explained

This document explains `.github/workflows/gitops-bootstrap-codespaces.yml`.

## Quick Reminder

1. Open Codespaces.
2. Make sure `.env` exists:

```bash
cp .env.example .env
```

3. Start the self-hosted runner in a dedicated terminal:

```bash
export GITHUB_REPOSITORY="OWNER/REPOSITORY"
make github-runner-start
```

4. Open GitHub:

```text
Repository -> Actions -> GitOps Bootstrap Codespaces -> Run workflow
```

5. First run:

```text
apply = false
destroy = false
```

This runs `plan` only.

On an empty Codespaces environment, this plans only the `codespaces` layer
because the `platform` layer needs a reachable Kubernetes context.

6. Create/update:

```text
apply = true
destroy = false
```

This applies `codespaces` first and `platform` second.

7. Return to the pre-cluster state:

```text
apply = true
destroy = true
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
name: GitOps Bootstrap Codespaces
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
apply:
  description: "Apply Terraform changes instead of only planning."
  required: true
  type: boolean
  default: false
```

Boolean input. `false` means plan only. `true` allows apply or destroy.

```yaml
destroy:
  description: "Destroy platform first and then delete the local k3d cluster."
  required: true
  type: boolean
  default: false
```

Boolean input. When `destroy=true` and `apply=true`, the workflow destroys
Terraform-managed resources instead of creating/updating them.

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
  if: ${{ !inputs.destroy }}
  run: terraform -chdir=infra/terraform/codespaces plan -out=tfplan
```

Plans k3d cluster creation/reuse only when not destroying.

```yaml
- name: Codespaces Terraform apply
  if: ${{ inputs.apply && !inputs.destroy }}
  run: terraform -chdir=infra/terraform/codespaces apply -auto-approve tfplan
```

Applies the saved k3d plan only when `apply=true` and `destroy=false`.

```yaml
- name: Platform Terraform plan
  if: ${{ !inputs.destroy }}
  env:
    TF_VAR_repository_url: ${{ github.server_url }}/${{ github.repository }}.git
    TF_VAR_target_revision: ${{ github.ref_name }}
  run: terraform -chdir=infra/terraform/platform plan -out=tfplan
```

Plans platform resources after the k3d cluster has been applied. The `TF_VAR_*`
environment variables become Terraform variables:

- `repository_url`: Git repo URL for Argo CD;
- `target_revision`: branch/tag for Argo CD.

```yaml
- name: Platform Terraform apply
  if: ${{ inputs.apply && !inputs.destroy }}
  run: terraform -chdir=infra/terraform/platform apply -auto-approve tfplan
```

Applies the saved platform plan after the k3d cluster exists.

```yaml
- name: Platform Terraform destroy
  if: ${{ inputs.destroy && inputs.apply }}
  env:
    TF_VAR_repository_url: ${{ github.server_url }}/${{ github.repository }}.git
    TF_VAR_target_revision: ${{ github.ref_name }}
  run: terraform -chdir=infra/terraform/platform destroy -auto-approve
```

Destroys the platform layer first. This removes Helm releases, namespaces and
GitOps bootstrap resources before the Kubernetes cluster disappears.

```yaml
- name: Codespaces Terraform destroy
  if: ${{ inputs.destroy && inputs.apply }}
  run: terraform -chdir=infra/terraform/codespaces destroy -auto-approve
```

Destroys the local Codespaces layer second. Its `terraform_data` destroy
provisioner deletes the k3d cluster.

## Safe Modes

Plan local cluster only:

```text
apply=false
destroy=false
```

Full platform planning requires a created cluster. Use `apply=true,
destroy=false` for the first end-to-end bootstrap run.

Create/update:

```text
apply=true
destroy=false
```

Destroy everything managed by Terraform:

```text
apply=true
destroy=true
```

`destroy=true, apply=false` is intentionally a no-op after validation/init.

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
