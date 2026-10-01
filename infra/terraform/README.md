# Terraform GitOps Bootstrap

Terraform is split into three layers:

- `codespaces`: disposable local k3d cluster lifecycle;
- `platform`: Argo CD and the GitOps bootstrap Helm release;
- `oracle`: placeholder for the future OCI VM/OKE/network layer.

After Argo CD is installed, Terraform creates the root Argo CD Application.
Argo CD then owns the operator, platform-runtime and service layers from Git.
The GitHub Actions flow is split in two so dependent runtime resources are not
deployed until the operator layer is already Synced/Healthy.

## Local Codespaces Flow

```bash
make terraform-init
make terraform-plan
make terraform-apply
```

`make terraform-plan` plans the local `codespaces` cluster layer only. The
`platform` layer needs a reachable Kubernetes context, so run
`make terraform-platform-plan` after the k3d cluster exists.

For the platform layer specifically:

```bash
make terraform-platform-plan
make terraform-platform-apply
```

If files changed after a previous plan, discard the old mental model and create
a fresh plan before applying.

`make terraform-apply` applies layers in this order:

```text
infra/terraform/codespaces
infra/terraform/platform
```

The initial Argo CD handoff is a small Helm release:

```text
resilient-orders-bootstrap -> resilient-orders-root -> infra/root
```

The first workflow bootstraps the operator layer through Argo CD:

```text
codespaces-cluster-bootstrap
  -> k3d
  -> Argo CD
  -> resilient-orders-root
  -> External Secrets Operator
  -> Gateway API CRDs / NGINX Gateway
```

The second workflow deploys only after that bootstrap is ready:

```text
codespaces-platform-deploy
  -> checks the cluster and watched Git branch
  -> commits keep/enable/disable choices to infra/root/values.yaml
  -> Argo CD installs selected operators first
  -> Argo CD enables platform-system
  -> Argo CD enables platform-runtime
  -> Argo CD enables selected services
```

The deploy workflow intentionally does not run Terraform. Terraform stays
responsible for the local cluster, Argo CD and the bootstrap handoff only.
Full cleanup stays in `codespaces-cluster-bootstrap mode=destroy`. Terraform
destroys bootstrap and waits for Argo's root finalizer, then removes Argo CD and k3d.
Component selection persists in Git, so recreating the cluster restores it.

Independently removable components have separate child Applications with waves.
Argo prunes them in reverse order; foreground finalizers wait for their resources.
RabbitMQ topology also uses internal waves for users/permissions/bindings.

The app layer enables the first lightweight service slice, `payment-service`.
The `payment-service` workflow publishes the service image to GHCR and updates
the GitOps image value in Git. Argo CD deploys that immutable image reference
from repository state, not from a live Application mutation.

## Cloud Migration Notes

For Oracle Cloud, replace only the cluster/runtime layer first:

- `infra/terraform/codespaces` is replaced by `infra/terraform/oracle`;
- Infisical can later be replaced by OCI Vault or another cloud secret provider
  behind the same External Secrets Operator contract;
- `infra/terraform/platform`, Argo CD Application paths and Helm charts can
  stay the same.

The current Codespaces bootstrap uses Infisical Universal Auth because
Infisical Cloud cannot safely call the local k3d Kubernetes API for
TokenReview. Application passwords stay in Infisical; the Universal Auth
Client ID/Secret are stored only in GitHub Actions secrets and the local
Terraform state used by the temporary self-hosted runner.

## Detailed Explanations

- [Terraform files explained](TERRAFORM_EXPLAINED.md)
- [Codespaces layer](codespaces/README.md)
- [Platform layer](platform/README.md)
- [Oracle placeholder](oracle/README.md)

## Cleanup

Preferred cleanup:

```bash
make terraform-destroy
```

This runs:

```text
terraform -chdir=infra/terraform/platform destroy
terraform -chdir=infra/terraform/codespaces destroy
```

The order matters: remove Kubernetes/Helm resources first, then delete the k3d
cluster. The Codespaces layer uses a `terraform_data` destroy provisioner to run:

```bash
k3d cluster delete resilient-orders
```

Terraform destroys the GitOps bootstrap Helm release before Argo CD.
That release owns the `resilient-orders-root` Application with the standard Argo
CD cascade finalizer. While Argo CD is still running, it can prune child
Applications, workloads and operator Applications before the controller itself
is removed.

Bootstrap repository/auth Secrets and root AppProject are retained by Helm while
the root finalizer runs. Platform-only destroy leaves them; full k3d deletion
removes them. No automatic finalizer removal or custom child-deletion script runs.

If Terraform state is unavailable, run the same fallback manually:

```bash
k3d cluster delete resilient-orders
```

Self-hosted GitHub runner cleanup is separate from Terraform:

```bash
make github-runner-cleanup
```

## Infisical Universal Auth For Codespaces

External Secrets Operator authenticates to Infisical with Universal Auth. The
platform-system chart renders:

```text
Secret/infisical-universal-auth
ClusterSecretStore/infisical-cluster-store
```

The Secret contains only the Infisical Universal Auth Client ID/Secret, not
PostgreSQL/RabbitMQ/Grafana/application passwords. This is acceptable for the
temporary Codespaces/dev environment, but the local Terraform state should stay
ignored and should not be copied into Git.

For a real cloud cluster, prefer Infisical Kubernetes Auth, OCI Auth or another
cloud identity flow where Infisical can safely validate workload identity
without exposing the Kubernetes API from Codespaces.
