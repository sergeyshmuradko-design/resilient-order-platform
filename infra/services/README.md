# Services

This group is for application service deployments.

The current first service slice contains `payment-service`. Future service
entries should add `order-service` and `notification-service` without changing
platform-system ownership.

Service-owned RabbitMQ topology lives here as `User`, `Permission`, `Exchange`,
`Queue` and `Binding` custom resources. Platform teams still own the broker
cluster itself; service teams own the messaging contract their application uses.

`infra/root` creates the services child Application and points it at this chart.
The production-style GitOps path promotes immutable image tags by changing this
chart's values through a reviewed pull request.
