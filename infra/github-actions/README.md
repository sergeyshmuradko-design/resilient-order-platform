# Codespaces Self-Hosted Runner

This helper is only for the temporary local learning setup.

The runner runs inside your Codespaces terminal and connects outbound to GitHub.
GitHub does not SSH into Codespaces. When you start a workflow, GitHub assigns
the job to this registered runner, and the runner executes the steps locally in
Codespaces where Docker, k3d, kubectl and your workspace are available.

Important for public repositories: do not allow untrusted pull request workflows
to run on this runner. The provided workflow uses only `workflow_dispatch` so
you start it manually.

## Required Local Tools

- `gh` authenticated to your GitHub account;
- `curl` and `tar`;
- Docker;
- k3d;
- kubectl;
- Helm;
- Terraform, or let the workflow install Terraform through
  `hashicorp/setup-terraform`.

## Start

### Daily Checklist

1. Open Codespaces for this repository.
2. Make sure Docker is responsive:

```bash
docker ps
```

3. Make sure GitHub CLI is authenticated:

```bash
gh auth status
```

4. Prepare local secrets once:

```bash
cp .env.example .env
```

Then edit `.env` locally. Do not commit it.

5. Start the runner in a dedicated terminal and leave that terminal open:

```bash
export GITHUB_REPOSITORY="OWNER/REPOSITORY"
make github-runner-start
```

6. In GitHub, open:

```text
Repository -> Actions -> GitOps Bootstrap Codespaces -> Run workflow
```

For the first run choose:

```text
apply = false
destroy = false
```

If the plan is acceptable, run the workflow again with:

```text
apply = true
destroy = false
```

To return Codespaces to the pre-cluster state:

```text
apply = true
destroy = true
```

7. Watch the runner terminal. A healthy idle runner prints that it is listening
for jobs. When the workflow starts, the terminal shows each GitHub Actions step.

8. Check Kubernetes after a successful apply:

```bash
kubectl get pods -n argocd
kubectl get applications -n argocd
kubectl get pods -n resilient-orders-platform
kubectl get externalsecret -n resilient-orders-platform
kubectl get secret platform-secrets -n resilient-orders-platform
helm list -A
```

9. Stop the runner:

```bash
Ctrl+C
```

The default runner is ephemeral, so after one completed job it unregisters
itself. For persistent runners use `make github-runner-cleanup`.

Terraform state for this local workflow is stored in the self-hosted runner
checkout directory and is ignored by Git. Keep using the same open Codespaces
runner directory for apply/destroy testing. If that local state is lost, delete
the local cluster manually:

```bash
k3d cluster delete resilient-orders
```

If `gh` is authenticated and has repository administration permission, the
script creates a short-lived runner registration token automatically. Otherwise
create a token in GitHub:

```text
Repository -> Settings -> Actions -> Runners -> New self-hosted runner
```

Then run:

```bash
export GITHUB_REPOSITORY="OWNER/REPOSITORY"
export RUNNER_TOKEN="token-from-github-ui"
make github-runner-start
```

## Cleanup

```bash
make github-runner-cleanup
```

If the runner is already gone from GitHub, this command may print a harmless
remove-token error. You can also delete the runner from GitHub UI under
repository runner settings.

## What Actually Happens

Starting the runner does not start Terraform. The sequence is:

1. `make github-runner-start` executes
   `infra/github-actions/start-codespaces-runner.sh`.
2. The script registers this Codespaces machine as a temporary GitHub Actions
   runner for the repository.
3. GitHub sees a runner with labels `self-hosted`, `codespaces`, `k3d`,
   `resilient-orders`.
4. The workflow job has `runs-on: [self-hosted, codespaces, k3d,
   resilient-orders]`, so GitHub can assign the job to this runner.
5. The runner downloads the workflow job payload from GitHub.
6. The runner executes workflow steps inside Codespaces.
7. The `actions/checkout` step checks out the repository into the runner work
   directory.
8. The `hashicorp/setup-terraform` step downloads Terraform for that job.
9. Terraform runs from `infra/terraform`.
10. The workflow plans or applies `infra/terraform/codespaces` first.
11. The workflow plans or applies `infra/terraform/platform` second.
12. With `destroy=true`, the workflow destroys `platform` first and then
    destroys `codespaces`, which deletes the k3d cluster.

## Script Explanation

Detailed line-by-line notes:

- [start-codespaces-runner.sh](RUNNER_SCRIPT_EXPLAINED.md#start-codespaces-runnersh)
- [cleanup-codespaces-runner.sh](RUNNER_SCRIPT_EXPLAINED.md#cleanup-codespaces-runnersh)
- [gitops-bootstrap-codespaces.yml](WORKFLOW_EXPLAINED.md)

Terraform bootstrap explanation:

- [Terraform files explained](../terraform/TERRAFORM_EXPLAINED.md)
