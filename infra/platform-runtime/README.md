# Platform Runtime

This group is for shared runtime infrastructure consumed by services:

- PostgreSQL;
- Redis;
- RabbitMQ;
- runtime HTTP routes;
- later Kafka, Schema Registry, tracing and monitoring slices.

RabbitMQ is deployed as a `RabbitmqCluster` custom resource. The RabbitMQ
Cluster Operator is installed by an Argo CD operator Application, while this chart
owns only the desired broker instance and its local resource limits.

`infra/root` creates separate PostgreSQL, Redis and RabbitMQ Applications from
this chart using `renderScope`. A retained extensions Application owns the future
Kafka/tracing/monitoring templates. Disabled future components keep their limits in
`values.yaml` so they can be enabled later without redesigning the profile.
