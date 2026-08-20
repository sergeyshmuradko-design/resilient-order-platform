# Platform Runtime

This group is for shared runtime infrastructure consumed by services:

- PostgreSQL;
- Redis;
- RabbitMQ;
- runtime HTTP routes;
- later Kafka, Schema Registry, tracing and monitoring slices.

RabbitMQ is deployed as a `RabbitmqCluster` custom resource. The RabbitMQ
Cluster Operator is installed by the Terraform platform layer, while this chart
owns only the desired broker instance and its local resource limits.

`infra/root` creates the platform-runtime child Application and points it at
this chart directly. Disabled future components keep their resource limits in
`values.yaml` so they can be enabled later without redesigning the profile.
