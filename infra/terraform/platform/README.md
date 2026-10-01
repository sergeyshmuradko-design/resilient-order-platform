# Platform Terraform Layer

This layer assumes Kubernetes already exists and `kubeconfig` points to it.

It installs the GitOps bootstrap platform:

- Argo CD;
- the GitOps bootstrap Helm release that creates the root Argo CD Application
  for `infra/root`;
- the Infisical Universal Auth settings passed into the GitOps bootstrap.

Terraform does not install platform operators directly. The root Argo CD
Application owns External Secrets Operator, Gateway API/NGINX Gateway,
cert-manager, RabbitMQ operators, Strimzi and Kyverno from Git.

Startup ordering is handled by workflow boundaries:

- `codespaces-cluster-bootstrap` creates root and waits for Git reconciliation;
- `codespaces-platform-deploy` commits component choices to root values;
  Argo CD installs them using dependency waves. One commit describes the final
  selection; Argo prunes whole component Applications in reverse waves.
- Destroy uninstalls bootstrap first and waits for the root foreground finalizer
  before removing Argo CD. There is no custom child-deletion script.

That gives a cleaner GitOps ownership model while avoiding startup races such as
ExternalSecret or RabbitMQ topology resources being submitted before their
operator CRDs/webhooks are ready.

RabbitMQ, Strimzi and Kyverno remain disabled by default to keep the first
Codespaces slice small. Enable them through workflow inputs when that slice is
being tested.

## Codespaces Apply

```bash
terraform -chdir=infra/terraform/codespaces apply
terraform -chdir=infra/terraform/platform init
terraform -chdir=infra/terraform/platform plan \
  -var="repository_url=https://github.com/OWNER/REPOSITORY.git"
terraform -chdir=infra/terraform/platform apply \
  -var="repository_url=https://github.com/OWNER/REPOSITORY.git"
```

External Secrets Operator reads application/runtime secrets from Infisical.
The bootstrap chart creates `infisical-universal-auth` with the Client
ID/Secret provided by GitHub Actions secrets. The actual
PostgreSQL/RabbitMQ/Grafana/application passwords stay in Infisical.

Per-service Applications use scopes of `infra/services/values.yaml`.
The `payment-service` workflow publishes the image
and commits the updated `components.paymentService.image` value to Git.

## Argo CD UI

Dex is disabled in the local chart values because this setup does not use SSO.
The Argo CD UI still works with the local `admin` user.

Get the initial admin password:

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d
```

The local k3d cluster publishes one Gateway port through:

```bash
--port '8080:80@loadbalancer'
```

If the platform was applied with the default Gateway controller enabled, open:

```text
http://argocd.localhost:8080
```

Login:

```text
username: admin
password: value from argocd-initial-admin-secret
```

Use port-forward only if the cluster was created without the k3d
`8080:80@loadbalancer` mapping:

```bash
kubectl port-forward -n argocd svc/argo-cd-argocd-server 8088:80
```

## Destroy

Destroy the platform before destroying the local cluster:

```bash
terraform -chdir=infra/terraform/platform destroy \
  -var="repository_url=https://github.com/OWNER/REPOSITORY.git"
terraform -chdir=infra/terraform/codespaces destroy
```

This removes the GitOps bootstrap release while Argo CD is still running. Argo
CD prunes child Applications and workloads first; then Terraform removes Argo CD
and the local k3d cluster.

Root AppProject and bootstrap repository/auth Secrets are intentionally retained
through Helm uninstall so cleanup can still use them. They remain after a
platform-only destroy and disappear with the full k3d cluster.
For a running old cluster, follow the [ownership migration procedure](../../root/README.md)
before pushing this chart restructuring to its watched branch.
