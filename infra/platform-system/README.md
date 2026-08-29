# Platform System

This group is for cluster-level and platform-system concerns:

- Argo CD projects and deployment boundaries;
- Infisical-backed External Secrets integration;
- Gateway API entry points;
- shared RBAC and namespace guardrails.

This chart intentionally does not own RabbitMQ exchanges, queues or bindings.
Messaging topology belongs to service contracts in `infra/services`; the
platform-system layer owns only shared plumbing and access boundaries.

`infra/root` creates the platform-system child Application and points it at this
chart directly. This folder is the future standalone platform-system repository
boundary.

## Kyverno Guardrails

Kyverno policies are disabled by default. When the Kyverno operator is enabled
from `infra/root/values.yaml`, enable this chart's policy layer with:

```yaml
policy:
  kyverno:
    enabled: true
    validationFailureAction: Audit
```

The default `Audit` mode reports violations without blocking resources. After
the reports are clean, switch to `Enforce` to reject unsafe manifests at
admission time.

Current guardrails:

- `order-service` and `notification-service` must keep
  `SPRING_RABBITMQ_DYNAMIC=false`;
- RabbitMQ `Queue.spec.arguments` is disallowed so runtime behaviour is managed
  by RabbitMQ `Policy` CRs;
- application/platform Deployments cannot use the mutable `latest` image tag;
- application/platform workloads must declare CPU and memory requests/limits.

## Infisical Contract

External Secrets Operator reads the following keys from the configured
Infisical project/environment/path and materializes them as `platform-secrets`:

```text
POSTGRES_PASSWORD
POSTGRES_EXPORTER_PASSWORD
ORDER_SERVICE_DB_OWNER_PASSWORD
ORDER_SERVICE_DB_PASSWORD
NOTIFICATION_SERVICE_DB_OWNER_PASSWORD
NOTIFICATION_SERVICE_DB_PASSWORD
JWT_SECRET
ORDER_SERVICE_RABBITMQ_USERNAME
ORDER_SERVICE_RABBITMQ_PASSWORD
NOTIFICATION_SERVICE_RABBITMQ_USERNAME
NOTIFICATION_SERVICE_RABBITMQ_PASSWORD
GRAFANA_ADMIN_USER
GRAFANA_ADMIN_PASSWORD
ORDER_SERVICE_ADMIN_USERNAME
ORDER_SERVICE_ADMIN_PASSWORD
ORDER_SERVICE_USER_USERNAME
ORDER_SERVICE_USER_PASSWORD
```

Infisical authentication uses Universal Auth in Codespaces:

- create a Machine Identity in Infisical with Universal Auth enabled;
- copy the Client ID into the GitHub repository secret
  `INFISICAL_UNIVERSAL_AUTH_CLIENT_ID`;
- copy the Client Secret into the GitHub repository secret
  `INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET`.

Kubernetes Auth is reserved for a future cloud/self-hosted setup where
Infisical can safely reach the Kubernetes TokenReview API.
