# Terraform GitOps Bootstrap

Terraform is split into three layers:

- `codespaces`: disposable local k3d cluster lifecycle;
- `platform`: controllers, namespaces, Argo CD and the first GitOps
  Application;
- `oracle`: placeholder for the future OCI VM/OKE/network layer.

After Argo CD is installed, Kubernetes workloads should be reconciled from Git.
That is the GitOps boundary: Terraform prepares the platform, Argo CD keeps the
cluster equal to repository state.

## Local Codespaces Flow

```bash
cp .env.example .env
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

The initial Argo CD application uses:

```text
infra/helm/admin
infra/helm/admin/values-postgres-only.yaml
```

That means the first verification slice is intentionally small: Gateway API,
Vault, ExternalSecret and PostgreSQL. Messaging operators and brokers stay out
of the default slice until they are explicitly enabled.

## Cloud Migration Notes

For Oracle Cloud, replace only the cluster/runtime layer first:

- `infra/terraform/codespaces` is replaced by `infra/terraform/oracle`;
- `local_env_file`/local Vault seed becomes OCI Vault or another cloud secret
  provider;
- `infra/terraform/platform`, Argo CD Application paths and Helm charts can
  stay the same.

The current local Vault seed scripts avoid writing application passwords into
`terraform.tfstate`. They are a Codespaces convenience, not a production secret
management model.

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

The GitHub Actions workflow performs one extra GitOps ordering step before the
platform destroy: it deletes the `resilient-orders-platform` Argo CD
Application with the standard Argo CD cascade finalizer while Argo CD is still
running. That lets Argo CD prune the resources it owns before Terraform removes
operators and namespaces.

If Terraform state is unavailable, run the same fallback manually:

```bash
k3d cluster delete resilient-orders
```

Self-hosted GitHub runner cleanup is separate from Terraform:

```bash
make github-runner-cleanup
```

## Why Not Put .env Secrets Into Vault Directly With Terraform?

Technically, we could make this shorter with the Vault provider:

```hcl
provider "vault" {
  address = "http://..."
  token   = var.vault_token
}

resource "vault_kv_secret_v2" "platform" {
  mount = "secret"
  name  = "resilient-orders"
  data_json = jsonencode({
    POSTGRES_PASSWORD = var.postgres_password
  })
}
```

But that has a serious downside: Terraform state would contain the secret
values. Even when variables are marked `sensitive`, Terraform still needs the
real values in state so it can compare and update resources later.

The current local approach is a little more verbose, but safer for a public
learning repository:

- `.env` stays outside Git;
- Terraform state does not store application passwords;
- Kubernetes receives only the local Vault bootstrap token as a short local
  convenience;
- application passwords are written into Vault by a tiny shell script;
- later, this script can be replaced by OCI Vault, HashiCorp Vault automation,
  or a cloud secret manager without changing application manifests.

So: the shortest Terraform-only solution exists, but the current split is the
better default for this project because it avoids teaching the bad habit of
putting real secret values into Terraform state.
