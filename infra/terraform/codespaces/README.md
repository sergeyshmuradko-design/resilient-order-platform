# Codespaces Terraform Layer

This layer manages only the disposable local k3d cluster used in Codespaces.

It uses Terraform's built-in `terraform_data` resource, not `hashicorp/null`.
`terraform_data` does not manage a cloud object by itself; it gives Terraform a
standard lifecycle wrapper for local commands.

## Apply

```bash
terraform -chdir=infra/terraform/codespaces init
terraform -chdir=infra/terraform/codespaces apply
```

The apply step creates or reuses:

```text
k3d cluster resilient-orders
kubectl context k3d-resilient-orders
```

## Destroy

```bash
terraform -chdir=infra/terraform/codespaces destroy
```

The destroy step runs the destroy-time provisioner:

```bash
k3d cluster delete resilient-orders || true
```

This returns Codespaces to the pre-cluster state. If Terraform state is lost,
run the same command manually.
