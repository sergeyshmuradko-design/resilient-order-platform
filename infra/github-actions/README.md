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

4. Optional for Docker Compose only: prepare local `.env` secrets once:

```bash
cp .env.example .env
```

Then edit `.env` locally. Do not commit it. The GitOps/Kubernetes bootstrap no
longer reads this file.

5. Configure Infisical settings in GitHub once:

```text
Repository -> Settings -> Secrets and variables -> Actions
```

Add repository secrets:

```text
INFISICAL_UNIVERSAL_AUTH_CLIENT_ID
INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET
```

Add repository variables:

```text
INFISICAL_HOST_API=https://app.infisical.com
INFISICAL_PROJECT_SLUG=<your-infisical-project-slug>
INFISICAL_ENVIRONMENT_SLUG=dev
INFISICAL_SECRETS_PATH=/
```

6. Start the runner in a dedicated terminal and leave that terminal open:

```bash
make github-runner-start
```

The script detects `GITHUB_REPOSITORY` from `gh` or `git remote` and pins a
known working GitHub Actions Runner version. Secrets are no longer loaded from
the local `.env` file during the GitOps bootstrap; the workflow receives
Infisical connection settings from GitHub Actions secrets and variables.

7. In GitHub, open:

```text
Repository -> Actions -> Codespaces Cluster Setup -> Run workflow
```

For the first run choose:

```text
mode = plan
```

If the plan is acceptable, run the workflow again with:

```text
mode = apply
```

To return Codespaces to the pre-cluster state:

```text
mode = destroy
```

8. Watch the runner terminal. A healthy idle runner prints that it is listening
for jobs. When the workflow starts, the terminal shows each GitHub Actions step.

9. Check Kubernetes after a successful apply:

```bash
kubectl get pods -n argocd
kubectl get applications -n argocd
kubectl get pods -n resilient-orders-platform
kubectl get externalsecret -n resilient-orders-platform
kubectl get secret platform-secrets -n resilient-orders-platform
helm list -A
```

10. Stop the runner:

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
export RUNNER_TOKEN="token-from-github-ui"
make github-runner-start
```

## Cleanup

```bash
make github-runner-cleanup
make github-runner-prune
```

If the runner is already gone from GitHub, this command may print a harmless
remove-token error. You can also delete the runner from GitHub UI under
repository runner settings.

`github-runner-prune` removes local workflow checkouts, diagnostics and old
runner binary folders under `.local/github-runner`. The bootstrap workflow also
marks the runner for pruning after a successful `mode=destroy` run; the start
script performs the prune only after the GitHub Actions job has fully exited.

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
10. With `mode=plan`, the workflow plans `infra/terraform/codespaces`.
11. With `mode=apply`, the workflow applies `codespaces`, then plans and
    applies `platform`.
12. With `mode=destroy`, Terraform destroys `platform` first. The platform
    layer removes the GitOps bootstrap Helm release before Argo CD, so Argo CD
    can prune child Applications while its controller is still running. Then the
    workflow destroys `codespaces`, which deletes the k3d cluster.
13. After a successful destroy, the runner start script prunes local runner
    working data so `.local/github-runner` does not keep growing.

## Script Explanation

Detailed line-by-line notes:

- [start-codespaces-runner.sh](RUNNER_SCRIPT_EXPLAINED.md#start-codespaces-runnersh)
- [cleanup-codespaces-runner.sh](RUNNER_SCRIPT_EXPLAINED.md#cleanup-codespaces-runnersh)
- [codespaces-cluster-setup.yml](WORKFLOW_EXPLAINED.md)

Terraform bootstrap explanation:

- [Terraform files explained](../terraform/TERRAFORM_EXPLAINED.md)

Service workflows:

- [payment-service CI/CD](PAYMENT_SERVICE_CICD.md)
