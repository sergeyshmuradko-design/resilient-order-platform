# Platform Terraform Layer

This layer assumes Kubernetes already exists and `kubeconfig` points to it.

It installs the GitOps bootstrap platform:

- Argo CD;
- the GitOps bootstrap Helm release that creates the root Argo CD Application
  for `infra/root`;
- the Infisical Universal Auth settings passed into the GitOps bootstrap.

External Secrets Operator, Gateway API CRDs, NGINX Gateway Fabric, RabbitMQ
operators and optional Strimzi are now Argo CD Applications rendered from
`infra/root`. Terraform passes shared bootstrap settings and pinned chart
versions into the root chart, but it does not manage those operators as
individual Terraform resources. Operator enable/disable flags live in
`infra/root/values.yaml`.

RabbitMQ operators are enabled by default because `infra/platform-runtime`
declares a `RabbitmqCluster` and `infra/services` declares RabbitMQ topology
custom resources. Strimzi remains disabled by default to keep the first
Codespaces slice small.

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
The platform-system chart creates `infisical-universal-auth` with the Client
ID/Secret provided by GitHub Actions secrets. The actual
PostgreSQL/RabbitMQ/Grafana/application passwords stay in Infisical.

The services Application currently uses `infra/services/values.yaml`. It
enables `payment-service`. The `payment-service` workflow publishes the image
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

This removes the GitOps bootstrap release while Argo CD is still running, then
removes Argo CD and finally the local k3d cluster.
