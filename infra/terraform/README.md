# Terraform GitOps Bootstrap

Terraform is split into three layers:

- `codespaces`: disposable local k3d cluster lifecycle;
- `platform`: Argo CD and the GitOps bootstrap Helm release;
- `oracle`: placeholder for the future OCI VM/OKE/network layer.

After Argo CD is installed, Kubernetes workloads and platform operators are
reconciled from Git. That is the GitOps boundary: Terraform prepares the
controller handoff, Argo CD keeps the cluster equal to repository state.

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

The root Application owns child Applications and keeps deployment order in one
place:

```text
resilient-orders-platform-system   -> infra/platform-system
resilient-orders-platform-runtime  -> infra/platform-runtime
resilient-orders-services          -> infra/services
```

The child Applications use Argo CD sync waves only at the layer boundary:
platform-system, platform-runtime and service workloads. Low-level Kubernetes
objects such as StatefulSets and Services do not carry ordering annotations.

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
k3d cluster delete resilient-orders || true
```

Terraform destroys the GitOps bootstrap Helm release before it destroys Argo CD.
That release owns the `resilient-orders-root` Application with the standard Argo
CD cascade finalizer. While Argo CD is still running, it can prune child
Applications and workloads before Terraform removes operators and namespaces.

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
