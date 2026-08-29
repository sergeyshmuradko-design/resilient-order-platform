# Kubernetes Ownership Map

This file is a navigation map for the Kubernetes/GitOps part of the project.
It explains who owns which folder, which namespace receives which resources,
and how to inspect the final rendered manifests without mentally expanding all
Helm templates by hand.

## Production Pattern

Large production platforms usually split responsibility like this:

- platform/bootstrap team owns cluster bootstrap controllers, CRDs, Argo CD,
  Secret Manager integration, Gateway controllers, admission policies and
  cluster-level guardrails;
- platform/runtime team owns shared runtime services such as PostgreSQL,
  RabbitMQ, Redis, Kafka, tracing and monitoring;
- service teams own service Deployments, HTTP routes, messaging topology,
  service-specific migrations and image promotion values;
- security/platform governance owns RBAC boundaries, namespace policies,
  AppProject restrictions, branch protection and review rules.

In a real company these boundaries are often enforced by separate repositories,
CODEOWNERS, protected branches, Argo CD projects, OPA/Kyverno policies and
identity-provider groups. In this learning monorepo the folder split represents
the same model without forcing a multi-repository setup too early.

## Folder Ownership

| Folder | Owner | Purpose |
| --- | --- | --- |
| `infra/terraform/codespaces` | platform/bootstrap | Local k3d cluster lifecycle for Codespaces. |
| `infra/terraform/platform` | platform/bootstrap | Installs Argo CD and the root GitOps bootstrap release. |
| `infra/bootstrap` | platform/bootstrap | Helm-managed Argo CD handoff: root AppProject and root Application. |
| `infra/root` | platform/bootstrap | Argo CD app-of-apps entry point, operator Applications, AppProjects and child Applications. |
| `infra/platform-system` | platform/security | Infisical/External Secrets source, Gateway entry points, shared config and guardrails. |
| `infra/platform-runtime` | platform/runtime | PostgreSQL, Redis, RabbitMQ cluster, future Kafka/tracing/monitoring runtime components. |
| `infra/services` | service teams | Service workloads, service routes, service-owned RabbitMQ topology, Kafka topics and image values. |
| `.github/workflows` | platform/build tooling | CI/CD and GitOps bootstrap workflows. |

## Namespace Map

| Namespace | Owner | Main Resources |
| --- | --- | --- |
| `argocd` | platform/bootstrap | Argo CD server, controller, repo server, root and child Applications. |
| `external-secrets` | platform/security | External Secrets Operator. |
| `rabbitmq-system` | platform/runtime | RabbitMQ Cluster Operator and Messaging Topology Operator. |
| `nginx-gateway` | platform/networking | NGINX Gateway Fabric controller. |
| `resilient-orders-platform` | platform/runtime | PostgreSQL, Redis, RabbitMQ cluster, monitoring/tracing runtime components. |
| `resilient-orders` | service teams | Application Deployments, HTTPRoutes, service-owned messaging topology and app namespace Secret copies. |

## Argo CD Model

Terraform does not apply every application manifest. It installs Argo CD and
then installs the small `infra/bootstrap` Helm chart:

```text
Terraform -> infra/bootstrap -> resilient-orders-root -> infra/root
```

The root chart then creates child Applications:

```text
infra/root
  -> resilient-orders-external-secrets    -> External Secrets Operator
  -> resilient-orders-gateway-api-crds    -> Gateway API CRDs
  -> resilient-orders-nginx-gateway       -> NGINX Gateway Fabric
  -> resilient-orders-rabbitmq-operator   -> RabbitMQ Cluster/Topology operators
  -> resilient-orders-platform-system   -> infra/platform-system
  -> resilient-orders-platform-runtime  -> infra/platform-runtime
  -> resilient-orders-services          -> infra/services
```

`Application` answers: what Git path should Argo CD sync into which namespace?

`AppProject` answers: what is this Application allowed to do? It restricts
source repositories, destination namespaces and Kubernetes resource kinds.

## RBAC And Access Boundaries

Kubernetes RBAC answers what a human, automation identity or ServiceAccount can
do through the Kubernetes API. It does not control RabbitMQ permissions inside
RabbitMQ itself.

Current local boundaries:

- `platform-workload` ServiceAccount is for platform/runtime Pods and has token
  mounting disabled by default;
- `app-workload` ServiceAccount is for service Pods and migration Jobs and also
  has token mounting disabled by default;
- `service-messaging-owner` Role in `infra/services` documents the future
  developer boundary for RabbitMQ topology CRDs in the application namespace.

RabbitMQ permissions are separate from Kubernetes RBAC:

- platform owns the `RabbitmqCluster`;
- service teams own RabbitMQ `User`, `Permission`, `Exchange`, `Queue` and
  `Binding` resources in `infra/services`;
- the Messaging Topology Operator reconciles those Kubernetes custom resources
  into the RabbitMQ broker.

## How To Inspect Rendered Manifests

Render one chart:

```bash
helm template resilient-orders-services infra/services \
  --namespace resilient-orders
```

Render everything into files:

```bash
mkdir -p /tmp/resilient-orders-rendered

helm template resilient-orders-root infra/root \
  --namespace argocd \
  --set repositoryUrl=https://github.com/OWNER/REPOSITORY.git \
  > /tmp/resilient-orders-rendered/root.yaml

helm template resilient-orders-platform-system infra/platform-system \
  --namespace resilient-orders-platform \
  > /tmp/resilient-orders-rendered/platform-system.yaml

helm template resilient-orders-platform-runtime infra/platform-runtime \
  --namespace resilient-orders-platform \
  > /tmp/resilient-orders-rendered/platform-runtime.yaml

helm template resilient-orders-services infra/services \
  --namespace resilient-orders \
  > /tmp/resilient-orders-rendered/services.yaml
```

List resource kinds in a rendered file:

```bash
grep -n '^kind:' /tmp/resilient-orders-rendered/services.yaml
```

Validate basic Helm structure:

```bash
helm lint infra/root
helm lint infra/platform-system
helm lint infra/platform-runtime
helm lint infra/services
```

After deployment, inspect Argo CD's view of ownership:

```bash
kubectl get applications -n argocd
kubectl describe application resilient-orders-services -n argocd
kubectl get appprojects -n argocd
kubectl describe appproject resilient-orders-services -n argocd
```

## Helpful Tools

These tools are commonly used to make Kubernetes easier to navigate:

- Argo CD UI: best first view for GitOps sync status, drift and resource tree;
- `helm template`: shows what Helm will actually send to Kubernetes;
- `kubectl describe`: explains one live resource, events and owner references;
- `kubectl auth can-i`: checks RBAC permissions;
- `kubeconform` or `kubeval`: validates rendered YAML against Kubernetes schemas;
- `kubectl-neat`: removes noisy runtime fields from live YAML;
- `rakkess` or `rbac-tool`: summarizes RBAC permissions;
- `stern`: streams logs from multiple matching Pods.

For this project, start with Argo CD UI, `helm template`, `kubectl describe`,
and `kubectl auth can-i`. The others are useful later when the cluster grows.
