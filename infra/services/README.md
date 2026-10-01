# Services

This group is for application service deployments.

The first service slice enables `payment-service`. Templates and resource limits
for `order-service` and `notification-service` are retained but disabled until
their database/messaging dependencies are ready.

Service-owned RabbitMQ topology lives here as `User`, `Permission`, `Exchange`,
`Queue` and `Binding` custom resources. Platform teams still own the broker
cluster itself; service teams own the messaging contract their application uses.

`infra/root` creates one Application per service and a separate RabbitMQ topology
Application. Each uses a disjoint `renderScope` of this chart. Shared Secrets,
ServiceAccount and RBAC belong to the base services Application.
Payment CI promotes its image by committing this chart's values through a
GitHub App. Image promotion does not change component selection.
