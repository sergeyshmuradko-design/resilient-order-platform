# Kubernetes GitOps Root

`infra/root` is the Argo CD app-of-apps entry point.

Terraform creates only the bootstrap handoff:

```text
resilient-orders-root -> infra/root
```

The root chart creates named Argo CD projects and child Applications:

```text
resilient-orders-external-secrets    -> External Secrets Operator, enabled by default
resilient-orders-gateway-api-crds    -> Gateway API CRDs, enabled by default
resilient-orders-nginx-gateway       -> NGINX Gateway Fabric, enabled by default
resilient-orders-cert-manager        -> cert-manager, disabled by default
resilient-orders-rabbitmq-operator   -> RabbitMQ Cluster/Topology operators, disabled by default
resilient-orders-kyverno             -> Kyverno policy engine, disabled by default
resilient-orders-platform-system   -> infra/platform-system
resilient-orders-platform-runtime  -> infra/platform-runtime
resilient-orders-services          -> infra/services, disabled by default for local bootstrap
```

Operator enable/disable switches are owned here, in `infra/root/values.yaml`.
Terraform only creates the root handoff and passes shared bootstrap settings
such as repository URL, target revision, namespaces and pinned chart versions.

The workflow can override the root switches without a Git commit by passing
Terraform variables into the bootstrap chart. The smallest local profile keeps
RabbitMQ and cert-manager disabled; `enable_rabbitmq_stack=true` enables the
RabbitMQ operators, the RabbitMQ runtime cluster and service-owned RabbitMQ
topology together.

External Secrets, Gateway API/NGINX Gateway, platform-system and
platform-runtime are treated as required platform pieces. Runtime dependencies
and applications are the selectable part: PostgreSQL, Redis, RabbitMQ stack,
Strimzi, Kyverno and each service can be enabled from workflow inputs.

Kyverno is disabled by default to keep the local Codespaces slice small. Enable
it by setting:

```yaml
operators:
  kyverno:
    enabled: true
```

Deployment order is kept at this boundary with Argo CD sync waves. Individual
workload resources such as Deployments, StatefulSets and Services do not carry
ordering annotations.

On delete, Argo CD prunes sync waves in reverse order. That keeps service and
runtime resources ahead of operator/controller removal.

Service image versions are stored in the service chart values. For the current
payment-service slice, the desired image lives here:

```text
infra/services/values.yaml
components.paymentService.image
```

The `payment-service` workflow updates that value after publishing the
payment-service image. Argo CD sees the Git change and deploys it.
