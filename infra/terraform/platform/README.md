# Platform Terraform Layer

This layer assumes Kubernetes already exists and `kubeconfig` points to it.

It installs the GitOps bootstrap platform:

- namespaces;
- External Secrets Operator;
- Strimzi Kafka Operator;
- Gateway API CRDs and NGINX Gateway Fabric;
- Argo CD;
- the first Argo CD Application for `infra/helm/admin`;
- local Vault bootstrap/seed helpers for Codespaces.

## Codespaces Apply

```bash
terraform -chdir=infra/terraform/codespaces apply
terraform -chdir=infra/terraform/platform init
terraform -chdir=infra/terraform/platform plan \
  -var="repository_url=https://github.com/OWNER/REPOSITORY.git"
terraform -chdir=infra/terraform/platform apply \
  -var="repository_url=https://github.com/OWNER/REPOSITORY.git"
```

The local Vault seed helper waits for Argo CD to create `deployment/vault` and
then waits for that Deployment to become available before writing `.env` values
into Vault.

## Argo CD UI

Dex is disabled in the local chart values because this setup does not use SSO.
The Argo CD UI still works with the local `admin` user.

Get the initial admin password:

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d
```

Open a local tunnel:

```bash
kubectl port-forward -n argocd svc/argo-cd-argocd-server 8088:80
```

Then open:

```text
http://localhost:8088
```

Login:

```text
username: admin
password: value from argocd-initial-admin-secret
```

## Destroy

Destroy the platform before destroying the local cluster:

```bash
terraform -chdir=infra/terraform/platform destroy \
  -var="repository_url=https://github.com/OWNER/REPOSITORY.git"
terraform -chdir=infra/terraform/codespaces destroy
```

This removes Helm releases, Terraform-managed namespaces, Argo CD bootstrap
resources and then the local k3d cluster.
