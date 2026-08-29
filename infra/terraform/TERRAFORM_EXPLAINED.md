# Terraform Files Explained

Terraform is now split by lifecycle:

- `infra/terraform/codespaces`: local disposable k3d cluster;
- `infra/terraform/platform`: Kubernetes platform bootstrap on an existing
  kube-context;
- `infra/terraform/oracle`: future Oracle Cloud placeholder.

This split keeps the platform reusable: Codespaces and Oracle can create
Kubernetes differently, but `platform` installs the same controllers and Argo CD
handoff.

## codespaces

`codespaces/versions.tf`

- `terraform { ... }`: Terraform CLI settings.
- `required_version = ">= 1.6.0"`: requires Terraform 1.6+.
- No external providers are declared because `terraform_data` is built in.

`codespaces/variables.tf`

- `k3d_cluster_name`: local cluster name, default `resilient-orders`.
- `k3d_http_port`: host port mapped to the k3d load balancer, default `8080`.

`codespaces/main.tf`

- `resource "terraform_data" "k3d_cluster"`: built-in Terraform lifecycle
  wrapper for local commands.
- `input`: stores cluster data so destroy provisioner can read it through
  `self.input.*`.
- `triggers_replace`: tells Terraform to replace the resource if cluster name
  or exposed port changes.
- first `local-exec`: creates the k3d cluster only if it does not already
  exist, then switches kubectl context.
- destroy `local-exec`: runs `k3d cluster delete ${self.input.cluster_name} ||
  true` during `terraform destroy`.

`codespaces/outputs.tf`

- `cluster_context`: prints the expected kubectl context.
- `cleanup_command`: prints the manual fallback command if Terraform state is
  unavailable.

## platform

`platform/versions.tf`

- requires Terraform 1.6+;
- declares only `hashicorp/helm`;
- configures Helm from `var.kubeconfig_path` and `var.kube_context`;
- no `hashicorp/null` provider is used.

`platform/variables.tf`

- `kubeconfig_path` and `kube_context`: tell Terraform which existing cluster to
  use.
- `repository_url` and `target_revision`: tell Argo CD which Git repo/revision
  to sync.
- namespace variables: platform, application, external-secrets, argocd,
  strimzi and nginx-gateway.
- `enable_argocd_application`: optional Terraform switch for creating the root
  Argo CD Application handoff.
- Infisical variables: project/environment/path plus the Universal Auth
  Client ID/Secret used by ESO in Codespaces.
- chart version variables: pinned versions for reproducible installs.

`platform/main.tf`

- `helm_release.argocd`: installs Argo CD with small local resource settings.
  Dex, ApplicationSet and notifications are disabled because the Codespaces
  setup does not use SSO, generated applications or alert fan-out.
- `helm_release.gitops_bootstrap`: installs `infra/bootstrap`, which creates
  the root Argo CD AppProject and Application. The root Application points to
  `infra/root`, which creates operator Applications first, then
  platform-system, platform-runtime and service workloads.

Terraform no longer owns Kubernetes namespaces, Gateway CRDs, External Secrets
Operator, RabbitMQ operators or NGINX Gateway Fabric as individual resources.
Those are GitOps resources reconciled by Argo CD from `infra/root`. Operator
enable/disable flags live in `infra/root/values.yaml`, not in Terraform.

`platform/outputs.tf`

- prints Argo CD, platform and application namespace names.

## oracle

`oracle` is intentionally empty for now. It will later create or attach to OCI
infrastructure: VM/OKE, network rules, disks and kubeconfig outputs.

## Why terraform_data

`terraform_data` is built into Terraform and replaces the old `hashicorp/null`
pattern for lifecycle wrappers around local provisioners. It reduces providers
and makes the intent clearer.

## Cleanup Order

Use:

```bash
make terraform-destroy
```

It destroys:

1. `platform`: GitOps bootstrap release first, then Argo CD.
2. `codespaces`: local k3d cluster through destroy provisioner.

Runner cleanup is separate:

```bash
make github-runner-cleanup
```
