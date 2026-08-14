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
- declares only `hashicorp/helm` and `hashicorp/kubernetes`;
- configures both providers from `var.kubeconfig_path` and `var.kube_context`;
- no `hashicorp/null` provider is used.

`platform/variables.tf`

- `kubeconfig_path` and `kube_context`: tell Terraform which existing cluster to
  use.
- `repository_url` and `target_revision`: tell Argo CD which Git repo/revision
  to sync.
- `local_env_file`: local-only path to `.env`, default `../../../.env`.
- namespace variables: platform, application, external-secrets, argocd,
  strimzi and nginx-gateway.
- feature flags: enable Strimzi, Gateway controller, local Vault seed, and Argo
  CD Application creation.
- chart version variables: pinned versions for reproducible installs.

`platform/main.tf`

- `locals.common_labels`: common Kubernetes labels for Terraform-managed
  namespaces.
- `kubernetes_namespace_v1.platform`: namespace for Vault/Postgres platform
  resources.
- `kubernetes_namespace_v1.application`: namespace reserved for services; it
  also receives the Gateway route label.
- `kubernetes_namespace_v1.external_secrets`: namespace for ESO.
- `kubernetes_namespace_v1.argocd`: namespace for Argo CD.
- optional `strimzi` and `nginx_gateway` namespaces are created only when their
  feature flags are true.
- `terraform_data.local_vault_token_secrets`: runs a shell helper that creates
  local bootstrap token Secrets without storing secret values in Terraform
  state.
- `helm_release.external_secrets`: installs External Secrets Operator and CRDs.
- `helm_release.strimzi`: installs Strimzi Kafka Operator.
- `terraform_data.gateway_api_crds`: applies Gateway API CRDs via `kubectl
  kustomize ... | kubectl apply -f -`.
- `helm_release.nginx_gateway`: installs NGINX Gateway Fabric.
- `helm_release.argocd`: installs Argo CD with small local resource settings.
  Dex is disabled because local Codespaces does not use SSO; the Argo CD UI
  still works with the built-in `admin` user.
- `terraform_data.argocd_platform_application`: renders the Argo CD Application
  template and applies it with `kubectl`.
- `terraform_data.local_vault_seed`: waits for Vault and writes `.env` values
  into local Vault.

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

1. `platform`: Helm releases, namespaces, Argo CD bootstrap resources.
2. `codespaces`: local k3d cluster through destroy provisioner.

Runner cleanup is separate:

```bash
make github-runner-cleanup
```
