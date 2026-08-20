# Kubernetes GitOps Root

`infra/root` is the Argo CD app-of-apps entry point.

Terraform creates only the bootstrap handoff:

```text
resilient-orders-root -> infra/root
```

The root chart creates named Argo CD projects and child Applications:

```text
resilient-orders-external-secrets    -> External Secrets Operator
resilient-orders-gateway-api-crds    -> Gateway API CRDs
resilient-orders-nginx-gateway       -> NGINX Gateway Fabric
resilient-orders-rabbitmq-operator   -> RabbitMQ Cluster/Topology operators
resilient-orders-platform-system   -> infra/platform-system
resilient-orders-platform-runtime  -> infra/platform-runtime
resilient-orders-services          -> infra/services
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
