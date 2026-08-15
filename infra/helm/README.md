# Resilient Orders Helm charts

These charts are the Kubernetes workload layer used by the GitOps flow. Terraform
bootstraps controllers and Argo CD; Argo CD reconciles these charts from Git.

The Helm tree is split by ownership:

- `infra/helm/admin` is the platform/admin chart for shared infrastructure;
- `infra/helm/app` is the developer chart for application workloads and app
  contracts;
- observability is enabled through values profiles;
- Kafka is managed by Strimzi custom resources instead of a hand-written
  Deployment;
- browser access is routed through Gateway API instead of several LoadBalancer
  Services;
- secrets are consumed from Kubernetes Secrets, and those Secrets can be
  produced by External Secrets Operator.

## Local secret flow

For local development, the `.env` file remains outside Git. Only the local Vault
bootstrap token is stored as a Kubernetes Secret; application secrets are seeded
into HashiCorp Vault:

```bash
make helm-vault-token-source
make helm-vault-seed
```

External Secrets Operator then copies data from Vault into the runtime
`platform-secrets` Secret used by the application Pods.

This is still a local rehearsal, not a full production Vault setup. In Oracle
Cloud the Vault provider block in `external-secrets-vault-source.yaml` can become
OCI Vault while the application Deployments keep reading the same
`platform-secrets` keys.

## Profiles

```bash
make helm-dev
make helm-monitoring
make helm-local-expose
make helm-local-gateway
make helm-template-postgres-only
make helm-prod-like
make helm-tracing
make helm-load
```

Use `make helm-template-monitoring` to render manifests locally without applying
anything to a Kubernetes cluster.

The default `values.yaml` is the dev profile. Additional values files are
overlays for one concern only, such as load testing or monitoring.

`infra/helm/admin/values-postgres-only.yaml` is the first GitOps profile. It
keeps Gateway, Vault, ExternalSecret and PostgreSQL enabled so the bootstrap can
be tested without the full application stack or messaging operators.

## Ownership model

Platform/admin-owned:

- installs External Secrets Operator, Strimzi and the Gateway API controller;
- owns platform namespace, Vault, shared infrastructure and Gateway policy;
- owns PostgreSQL bootstrap conventions, role model and default privileges;
- owns shared infrastructure limits, retention and Gateway policy.

Developer-owned:

- provides service Flyway migrations;
- declares Kafka topics under `components.kafka.topics`;
- declares HTTP routes under `routes`;
- updates the application Deployment values for the new service.

Service migrations should not be executed by the application in the future
prod-like path. The intended GitOps direction is: CI builds service and migration
images, pushes them to a registry, and Argo CD syncs Kubernetes Jobs/Deployments
from Git.

Database roles and schemas are platform-owned. Adding a service database
contract means changing `database.services` in the admin chart, which is the
small, reviewable contract between app and platform teams. The platform chart
generates roles, schemas and default privileges from that metadata.

## Local run

Create a local k3d cluster:

```bash
k3d cluster create resilient-orders \
  --servers 1 \
  --agents 0 \
  --port '8080:80@loadbalancer' \
  --k3s-arg '--disable=traefik@server:0'
```

Build and import local service images:

```bash
docker compose build order-service payment-service notification-service

k3d image import \
  resilient-orders/order-service:local \
  resilient-orders/payment-service:local \
  resilient-orders/notification-service:local \
  -c resilient-orders
```

Render the first GitOps slice locally without touching a cluster:

```bash
make helm-template-postgres-only
```

For the full local manual Helm flow, use `make helm-prod-like`. For GitOps, use
Terraform from [infra/terraform/README.md](../terraform/README.md).

Check runtime state:

```bash
kubectl get pods -n resilient-orders-platform
kubectl get pods -n resilient-orders
kubectl get strimzi -n resilient-orders-platform
kubectl get externalsecret -n resilient-orders-platform
kubectl get externalsecret -n resilient-orders
kubectl get secret platform-secrets -n resilient-orders
```

The local Gateway profile keeps application Services internal and exposes them
through one Gateway controller endpoint. Open:

- http://order.localhost:8080
- http://argocd.localhost:8080
- http://vault.localhost:8080
- http://grafana.localhost:8080
- http://prometheus.localhost:8080

In k3d, the `--port '8080:80@loadbalancer'` flag publishes one Docker host port
to the Gateway controller. In a cloud cluster, a real cloud load balancer would
usually sit in front of the Gateway controller.

Legacy LoadBalancer exposure is still available for comparison:

```bash
make helm-local-expose
```

If the cluster was created without published k3d ports, use port-forward:

```bash
kubectl port-forward -n resilient-orders-platform svc/grafana 3000:3000
kubectl port-forward -n resilient-orders-platform svc/prometheus 9090:9090
kubectl port-forward -n resilient-orders svc/order-service 8081:8081
```

Full cleanup:

```bash
make helm-delete-all
k3d cluster delete resilient-orders
```

## Baseline

RAM:
total 7.8 GiB
used 4.8 GiB
free 155 MiB
available 3.0 GiB
swap 0

Disk:
32 GiB total
19 GiB used
12 GiB available
62% used

Docker:
Images: 14, 6.632 GB
Containers: 1 total, 0 running
Volumes: 11, 6.599 MB
Build cache: 917 MB

Running Docker containers:
none

Главные процессы по памяти:
Java language server ~16.1% RAM
VS Code extension host ~7.7% RAM
Gradle daemon ~6.6% RAM
Еще один Gradle/Java process ~6.5% RAM
Spring Boot language server ~3.2% RAM
