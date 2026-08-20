# resilient-order-platform

## Table of Contents

- [Start Service](#start-service)
- [Helm / Kubernetes](#helm--kubernetes)
- [Clean Environment](#clean-environment)
- [Docker Managing](#docker-managing)
- [Graylog Managing](#graylog-managing)
- [Kafka Managing](#kafka-managing)
- [Git Managing](#git-managing)
- [Linux Managing](#linux-managing)
- [Swagger](#swagger)
- [Curl Examples](#curl-examples)
- [Redis Managing](#redis-managing)
- [Check Rate Limiter](#check-rate-limiter)
- [Test RabbitMQ](#test-rabbitmq)
- [Test Transactional Outbox](#test-transactional-outbox)
- [Test Kafka Event](#test-kafka-event)
- [Check Jaeger](#check-jaeger)
- [Check Prometheus](#check-prometheus)
- [Prometheus Metrics](#prometheus-metrics)

## Related Documentation

- [Order Service](services/order-service/README.md)
- [Payment Service](services/payment-service/README.md)
- [Notification Service](services/notification-service/README.md)
- [Performance Tests](performance-tests/README.md)
- [Eclipse Memory Analyzer](infra/mat/README.md)
- [Grafana Dashboards and Provisioning](infra/grafana/README.md)
- [Kubernetes Ownership Map](infra/KUBERNETES_OWNERSHIP.md)
- [GitOps Bootstrap Helm Chart](infra/bootstrap/README.md)
- [Kubernetes GitOps Root](infra/root/README.md)
- [Terraform GitOps Bootstrap](infra/terraform/README.md)
- [Codespaces GitHub Actions Runner](infra/github-actions/README.md)

## Helm / Kubernetes

Helm is the production-shaped path for running the platform in Kubernetes. The
current chart is lightweight and keeps strict resource limits and short
retention windows for local/k3d or small VM environments.

### Requirements

Install or enable:

- Docker
- kubectl
- Helm
- k3d or another Kubernetes cluster

Terraform creates and deletes the local k3d cluster through
`infra/terraform/codespaces`.

### Build and load local images

```bash
docker compose build order-service payment-service notification-service

k3d image import \
  resilient-orders/order-service:local \
  resilient-orders/payment-service:local \
  resilient-orders/notification-service:local \
  -c resilient-orders
```

### Start with GitOps

The GitOps path starts from Terraform. Terraform prepares the local Kubernetes
cluster, installs Argo CD, installs one GitOps bootstrap release, and then Argo
CD reconciles platform operators and workloads from Git.

```bash
make terraform-init
make terraform-plan
make terraform-apply
```

The first GitOps slice is deliberately small:

- Argo CD
- External Secrets Operator
- Strimzi Kafka Operator
- Gateway API CRDs and NGINX Gateway Fabric
- PostgreSQL

PostgreSQL is reconciled as the first platform workload. Secrets are read from
Infisical through External Secrets Operator. RabbitMQ, Kafka, Schema Registry,
services and observability stay in Helm values for later stages.

### Start from GitHub Actions

For Codespaces, use a self-hosted GitHub Actions runner because GitHub-hosted
runners cannot access your Codespaces Docker daemon or local kubeconfig.

In one Codespaces terminal:

```bash
export GITHUB_REPOSITORY="OWNER/REPOSITORY"
make github-runner-start
```

Then run the manual workflow in GitHub:

```text
Actions -> Codespaces Cluster Setup -> Run workflow
```

Use `mode=plan` for a plan, `mode=apply` to create/update, and `mode=destroy`
to remove platform resources and delete the local k3d cluster.

The runner waits for the workflow job. Terraform does not start automatically
when the runner starts.

### Check status

```bash
kubectl get pods -n resilient-orders-platform
kubectl get pods -n resilient-orders
kubectl get pods -n argocd
kubectl get applications -n argocd
kubectl get pods -n strimzi-system
kubectl get externalsecret -n resilient-orders-platform
kubectl get secret platform-secrets -n resilient-orders-platform
helm list -A
```

### Open UIs

In Docker Compose, ports are published directly with mappings like
`"3000:3000"`. In Kubernetes, Services stay internal by default and traffic is
routed through Gateway API.

With the local k3d command above, one host port is published:

- Order Service: http://order.localhost:8080
- Grafana: http://grafana.localhost:8080
- Prometheus: http://prometheus.localhost:8080

If you do not install the Gateway controller, use `kubectl port-forward`
instead:

```bash
kubectl port-forward -n resilient-orders-platform svc/grafana 3000:3000
kubectl port-forward -n resilient-orders-platform svc/prometheus 9090:9090
kubectl port-forward -n resilient-orders svc/order-service 8081:8081
```

Stop port forwarding with `Ctrl+C` in the terminal where it is running.

### Resource impact

This stack is heavier than Docker Compose because Kubernetes itself also runs
control-plane components. For a local k3d/k3s demo, expect approximately:

- Kubernetes/k3d baseline: 300-700 MB RAM
- External Secrets Operator: 50-150 MB RAM
- Strimzi Operator: roughly 100-300 MB RAM under the configured limits
- NGINX Gateway Fabric: roughly 100-250 MB RAM under the configured limits
- application stack without monitoring: roughly 1.8-3.0 GB RAM under the current limits
- monitoring profile: additional 400-700 MB RAM for Grafana, Prometheus and postgres-exporter
- persistent storage requests: Postgres 512 MiB, RabbitMQ 512 MiB, Kafka 512 MiB, namespace quota up to 3 GiB
- ephemeral retention: Prometheus `emptyDir` 256 MiB, Grafana `emptyDir` 128 MiB

In practice, the real usage should be lower than the limits when the system is
idle, but image storage will still consume disk space. The heaviest images are
usually Grafana, Schema Registry, Strimzi/Kafka and the Spring Boot service
images.

### Full cleanup

Remove all Kubernetes resources created for this project:

```bash
make terraform-destroy
```

This destroys the platform layer first and then runs the Codespaces layer
destroy provisioner, which deletes the local k3d cluster. If Terraform state is
lost, the equivalent manual fallback is:

```bash
k3d cluster delete resilient-orders
```

If a persistent self-hosted runner is still registered, clean it up:

```bash
make github-runner-cleanup
```

Verify that nothing project-related is still running:

```bash
kubectl get pods -A
helm list -A
docker ps
```

## start service
./gradlew :services:notification-service:build :services:order-service:build
./gradlew :services:notification-service:build :services:order-service:build :services:payment-service:build --refresh-dependencies
docker compose up -d postgres redis rabbitmq kafka schema-registry jaeger
./gradlew :services:order-service:bootRun
./gradlew :services:notification-service:bootRun \
  --args='--server.port=8084'

./gradlew :services:order-service:clean :services:order-service:bootJar
docker compose rm -f notification-service order-service payment-service
docker compose up -d --build
docker build -t resilient-orders/order-service:local services/order-service
docker build -t resilient-orders/notification-service:local services/notification-service
docker build -t resilient-orders/payment-service:local services/payment-service
sudo chmod 666 order-service-oom.hprof

## clean environment

./gradlew --stop
docker-compose stop
docker builder prune (удалит build cache)
docker volume inspect resilient-order-platform_kafka_data
docker volume rm resilient-order-platform_kafka_data

## docker managing

docker system df -v (Общий Docker usage)
df -h (Посмотреть память/место)
free -h
docker volume ls (Только список volume’ов)
docker run --rm -v resilient-order-platform_kafka_data:/data busybox du -sh /data (Посмотреть размер конкретного volume через du)
docker run --rm -v resilient-order-platform_kafka_data:/data busybox ls -lah /data (Посмотреть содержимое)
docker builder prune (удалит build cache)
docker compose --profile observability rm -f
docker volume rm resilient-order-platform_kafka_data
docker volume prune (Удалить anonymous volumes)
docker compose up -d --force-recreate fluent-bit (recreate container)
docker inspect resilient-orders-order-service \
  --format='restartCount={{.RestartCount}} status={{.State.Status}} oomKilled={{.State.OOMKilled}}'

docker compose config
docker compose --profile observability up -d --force-recreate
docker compose --profile observability up -d
docker compose --profile observability up -d --no-deps fluent-bit
docker compose up -d postgres redis rabbitmq kafka schema-registry jaeger order-service notification-service
docker ps
docker exec -it resilient-orders-postgres psql -U orders_user -d orders_db
\q
docker compose stop
docker compose --profile observability stop

## graylog managing

docker compose rm -f graylog-opensearch graylog
docker compose up -d graylog-mongodb graylog-opensearch graylog
docker logs resilient-orders-graylog --tail=50
docker logs resilient-orders-graylog-opensearch --tail=80
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
http://localhost:9000
System -> Inputs -> GELF UDP
Title: Local GELF UDP
Bind address: 0.0.0.0
Port: 12201
curl -i http://localhost:8081/actuator/health
docker compose stop

## kafka managing

### generate avro classes
./gradlew :services:order-service:generateAvroJava

### run kafka
docker compose up -d kafka schema-registry

### check kafka
docker logs resilient-orders-kafka --tail=50
docker logs resilient-orders-schema-registry --tail=80
curl http://localhost:8085/subjects
curl http://localhost:8085/subjects/order.created.events.avro-value/versions
curl http://localhost:8085/config/order.created.events.avro-value

### create kafka topic
docker exec -it resilient-orders-kafka \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic order.created.events \
  --partitions 3 \
  --replication-factor 1

docker exec -it resilient-orders-kafka \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic order.created.events.DLT \
  --partitions 3 \
  --replication-factor 1

### delete kafka topic
docker exec -it resilient-orders-kafka \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --delete \
  --topic order.created.events

### lookup kafka topic
docker exec -it resilient-orders-kafka \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list

## lookup producer console

docker exec -it resilient-orders-kafka \
  /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic order.created.events

### lookup kafka message

docker exec -it resilient-orders-kafka \
  /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic order.created.events \
  --from-beginning \
  --max-messages 1

docker exec -it resilient-orders-kafka \
  /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic order.created.events.DLT \
  --from-beginning \
  --max-messages 1

### lookup kafka consumer group

docker exec -it resilient-orders-kafka \
  /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --group notification-service

## git managing

git status
git add .
git commit -m ""
git push

## linux managing

mkdir -p services/order-service/src/main/java/com/example/orderservice
touch services/order-service/build.gradle

## swagger

http://127.0.0.1:8081/swagger-ui/index.html

## curl examples

for i in {1..5}; do
  curl -X POST http://localhost:8081/orders \
    -H "Content-Type: application/json" \
    -H "X-Correlation-Id: DB-POOL-$i" \
    -d "{\"customerId\":\"CUST-$i\",\"productId\":\"PROD-1\",\"quantity\":2}" &
done
wait

curl -X POST http://localhost:8081/orders -H "Content-Type: application/json" -H "X-Correlation-Id: TEST-12345" -d '{"customerId":"CUST-1","productId":"PROD-1","quantity":2}'
{"orderId":"eaaa6caf-5836-40bf-82a0-2563faec8d59","customerId":"CUST-1","productId":"PROD-1","quantity":2,"status":"CREATED","createdAt":"2026-05-24T18:31:49.317713148Z"}

curl -X POST http://localhost:8081/orders -H "Content-Type: application/json" -d '{"customerId":"CUST-1","productId":"PROD-1","quantity":2}'
{"orderId":"eaaa6caf-5836-40bf-82a0-2563faec8d59","customerId":"CUST-1","productId":"PROD-1","quantity":2,"status":"CREATED","createdAt":"2026-05-24T18:31:49.317713148Z"}

---

## run services

./gradlew :services:order-service:bootRun

## redis managing

docker exec -it resilient-orders-redis redis-cli [KEYS *] [FLUSHALL] [exit]

curl -H "Authorization: Bearer $TOKEN"  "http://localhost:8081/orders?customerId=CUST-1&status=CREATED&page=0&size=10"
curl -H "Authorization: Bearer $TOKEN" -s -X POST http://localhost:8081/orders \
    -H "Content-Type: application/json" \
    -d "{\"customerId\":\"CUST-test\",\"productId\":\"PROD-test\",\"quantity\":2}"

---

for i in {1..100}; do
  curl -s -X POST http://localhost:8081/orders \
    -H "Content-Type: application/json" \
    -d "{\"customerId\":\"CUST-$((i % 10))\",\"productId\":\"PROD-$i\",\"quantity\":2}" > /dev/null
done

curl "http://localhost:8081/orders?customerId=CUST-1&status=CREATED"

curl "http://localhost:8081/actuator/metrics/http.server.requests"

EXPLAIN ANALYZE
SELECT * FROM orders
WHERE customer_id = 'CUST-1'
AND order_status = 'CREATED';

CREATE INDEX idx_orders_customer_status
ON orders(customer_id, order_status);

---

curl "http://localhost:8081/orders/export/bad?status=CREATED" > /dev/null
curl "http://localhost:8081/orders/export/stream?status=CREATED" > /dev/null

curl "http://localhost:8081/actuator/metrics/jvm.memory.used?tag=area:heap" 7.5177832E7 8.4615016E7 8.6712168E7 9.5944704E7 1.11673344E8 1.04333312E8 1.09576192E8
curl "http://localhost:8081/actuator/metrics/jvm.gc.pause"
curl "http://localhost:8081/actuator/metrics/http.server.requests"

---

curl "http://localhost:8081/exports/ee3f6d37-81e5-49c2-9d8e-95c938968715"
curl -o orders.csv "http://localhost:8081/exports/b1ac03e2-f0b0-4201-bf57-a63a071effe5/download"

for i in {1..5}; do
  curl -s -X POST "http://localhost:8081/exports?status=CREATED" &
done
wait

curl "http://localhost:8081/actuator/metrics" | grep bulkhead
curl "http://localhost:8081/actuator/metrics/resilience4j.bulkhead.available.concurrent.calls?tag=name:exportJobBulkhead"
curl "http://localhost:8081/exports/5848f984-8a8a-401a-931a-cb1ff8679521/download"

curl -i "http://localhost:8081/orders?customerId=CUST-1&status=CREATED"
curl http://localhost:8081/actuator/health

---

export ORDER_SERVICE_ADMIN_USERNAME="<local-admin-username>"
export ORDER_SERVICE_ADMIN_PASSWORD="<local-admin-password>"

TOKEN=$(curl -s -X POST http://localhost:8081/auth/token \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${ORDER_SERVICE_ADMIN_USERNAME}\",\"password\":\"${ORDER_SERVICE_ADMIN_PASSWORD}\"}" \
  | jq -r '.accessToken')

echo $TOKEN

curl -i -H "Authorization: Bearer $TOKEN" \
  -X POST "http://localhost:8081/exports?orderStatus=CREATED"

---

## check rate limiter

for i in {1..7}; do
  curl -i -X POST http://localhost:8081/auth/token \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"wrong"}'
done

---

## test rabbitmq

curl -i -H "Authorization: Bearer $TOKEN" \
  -X POST http://localhost:8081/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId":"CUST-RABBIT","productId":"PROD-1","quantity":2}'

## test transactional outbox

curl -i -H "Authorization: Bearer $TOKEN" \
  -X POST http://localhost:8081/outbox/publish

## test kafka event

curl -i -H "Authorization: Bearer $TOKEN" \
  -X POST http://localhost:8081/kafka/publish-test

for i in {1..10}; do
  curl -s -H "Authorization: Bearer $TOKEN" \
    -X POST http://localhost:8081/kafka/publish-test
done

echo '{"messageId":"BAD-1","orderId":"ORDER-BAD-1","customerId":"CUST","productId":"PROD","quantity":"not-a-number","amount":99.99,"createdAt":"2026-06-30T12:00:00Z"}' | docker exec -i resilient-orders-kafka \
  /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic order.created.events

echo '{"messageId":"GOOD-1","orderId":"ORDER-GOOD-1","customerId":"CUST","productId":"PROD","quantity":1,"amount":99.99,"createdAt":"2026-06-30T12:00:00Z"}' | docker exec -i resilient-orders-kafka \
  /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic order.created.events

## test avro

cat > /tmp/bad-order-schema.json <<'EOF'
{
  "schema": "{\"type\":\"record\",\"name\":\"OrderCreatedEvent\",\"namespace\":\"com.example.orderservice.avro\",\"fields\":[{\"name\":\"messageId\",\"type\":\"string\"},{\"name\":\"orderId\",\"type\":\"string\"},{\"name\":\"customerId\",\"type\":\"string\"},{\"name\":\"productId\",\"type\":\"string\"},{\"name\":\"quantity\",\"type\":\"string\"},{\"name\":\"amount\",\"type\":\"double\"},{\"name\":\"createdAt\",\"type\":\"string\"},{\"name\":\"source\",\"type\":\"string\",\"default\":\"order-service\"}]}"
}
EOF

curl -X POST \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data @/tmp/bad-order-schema.json \
  http://localhost:8085/compatibility/subjects/order.created.events.avro-value/versions/latest

## check jaeger

curl -i http://localhost:8081/actuator/health

curl -i -H "Authorization: Bearer $TOKEN" \
  http://localhost:8081/orders?customerId=CUST-1

curl -i -H "Authorization: Bearer $TOKEN" \
  -X POST http://localhost:8081/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId":"CUST-TRACE","productId":"PROD-1","quantity":2}'

## check prometheus

curl http://localhost:8081/actuator/prometheus
curl http://localhost:8083/actuator/prometheus

curl -s http://localhost:8081/actuator/prometheus \
  | grep -E "http_server|jvm_memory|jvm_gc|process_cpu|hikaricp|tomcat_threads" \
  | head -100

### load test jvm

sum(jvm_memory_used_bytes{
  job="order-service",
  area="heap"
})

100 *
sum(jvm_memory_used_bytes{
  job="order-service",
  area="heap"
})
/
sum(jvm_memory_max_bytes{
  job="order-service",
  area="heap"
})

time curl -i \
  -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8081/internal/load-test/memory?megabytes=120&holdMilliseconds=10000"

sum(jvm_memory_used_bytes{
  job="order-service",
  area="heap"
})

jvm_memory_used_bytes{
  job="order-service",
  id=~".*Old.*"
}

rate(jvm_gc_pause_seconds_count{
  job="order-service"
}[1m])

rate(jvm_gc_pause_seconds_sum{
  job="order-service"
}[1m])

process_cpu_usage{
  job="order-service"
}

### load test Hikari

time curl -i \
  -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8081/internal/load-test/database?milliseconds=1000"

curl -i \
  "http://localhost:8081/internal/load-test/database?milliseconds=1000"

seq 1 20 | xargs -n1 -P20 -I{} \
  curl -s \
  -o /dev/null \
  -w "request={} status=%{http_code} time=%{time_total}\n" \
  -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8081/internal/load-test/database?milliseconds=5000"

promql:

hikaricp_connections_active{job="order-service"}

hikaricp_connections_max{job="order-service"}

hikaricp_connections_pending{job="order-service"}

hikaricp_connections_timeout_total{job="order-service"}

p95 for load-test endpoint:

histogram_quantile(
  0.95,
  sum by (le) (
    rate(http_server_requests_seconds_bucket{
      job="order-service",
      uri="/internal/load-test/database"
    }[5m])
  )
)

Ошибки endpoint:

sum by (status) (
  rate(http_server_requests_seconds_count{
    job="order-service",
    uri="/internal/load-test/database"
  }[5m])
)

процент ошибок:

100 *
sum(
  rate(http_server_requests_seconds_count{
    job="order-service",
    uri="/internal/load-test/database",
    status=~"5.."
  }[5m])
)
/
sum(
  rate(http_server_requests_seconds_count{
    job="order-service",
    uri="/internal/load-test/database"
  }[5m])
)

---

Heap usage в процентах:

100 *
sum(jvm_memory_used_bytes{
  job="order-service",
  area="heap"
})
/
sum(jvm_memory_max_bytes{
  job="order-service",
  area="heap"
})

jvm_memory_used_bytes{
  job="order-service",
  area="heap"
}

jvm_memory_used_bytes{
  job="order-service",
  id=~".*Old.*"
}

---

Количество пауз в секунду:

rate(jvm_gc_pause_seconds_count{
  job="order-service"
}[5m])

Суммарная доля времени в GC:

rate(jvm_gc_pause_seconds_sum{
  job="order-service"
}[5m])

Средняя пауза:

rate(jvm_gc_pause_seconds_sum{
  job="order-service"
}[5m])
/
rate(jvm_gc_pause_seconds_count{
  job="order-service"
}[5m])

Allocation pressure:

jvm_gc_memory_allocated_bytes_total{
  job="order-service"
}

rate(jvm_gc_memory_allocated_bytes_total{
  job="order-service"
}[5m])

---

CPU и GC вместе:

process_cpu_usage{job="order-service"}

rate(jvm_gc_pause_seconds_sum{job="order-service"}[5m])

Типичные выводы:

heap высокий, GC редкий, latency нормальная
→ JVM просто использует доступную память

heap быстро растёт и падает, GC частый
→ высокая allocation pressure

Old Gen растёт, после GC почти не уменьшается
→ возможная утечка или неограниченный cache

GC pauses растут вместе с p95/p99
→ GC начинает влиять на пользователей

---

Threads:

jvm_threads_live_threads{job="order-service"}

jvm_threads_peak_threads{job="order-service"}

tomcat_threads_busy_threads{job="order-service"}

tomcat_threads_config_max_threads{job="order-service"}

Интерпретация:

Tomcat busy близко к max
→ HTTP thread pool насыщен

JVM threads постоянно растут
→ возможна утечка потоков или неконтролируемое создание executors

threads много, CPU низкий
→ большинство потоков чего-то ждут

## Prometheus Metrics

### RED — состояние сервиса

Для HTTP, Kafka consumers, Rabbit listeners и других операций:

R — Rate: сколько операций в секунду
E — Errors: сколько ошибок
D — Duration: сколько занимает обработка

Для HTTP API:

http_server_requests_seconds_count
http_server_requests_seconds_sum
http_server_requests_seconds_bucket

### USE — насыщение ресурсов

Для CPU, памяти, thread pools, connection pools:

U — Utilization: насколько ресурс занят
S — Saturation: есть ли очередь/ожидание
E — Errors: ошибки ресурса

Например для Hikari:

active connections
idle connections
pending threads
max connections
timeouts

### Ключевые группы метрик

#### HTTP

Типичные метрики:

http_server_requests_seconds_count
http_server_requests_seconds_sum
http_server_requests_seconds_bucket

Смотрим:

RPS;
долю 4xx;
долю 5xx;
p95/p99;
самые медленные URI;
рост latency при росте нагрузки.

Интерпретация:

RPS растёт, latency растёт, CPU высокий
→ возможен кандидат на horizontal scaling

RPS стабильный, latency растёт, DB pool pending растёт
→ масштабирование приложения может сделать хуже;
  bottleneck в БД

RPS низкий, latency высокая только у одного endpoint
→ вероятнее запрос/код/внешняя зависимость, а не нехватка инстансов

#### JVM heap и GC

Типичные метрики:

jvm_memory_used_bytes
jvm_memory_max_bytes
jvm_gc_pause_seconds_count
jvm_gc_pause_seconds_sum
jvm_threads_live_threads
jvm_threads_peak_threads

Интерпретация:

heap после GC постоянно возвращается примерно на прежний уровень
→ нормально

heap после каждого GC остаётся всё выше
→ возможна утечка или слишком большой retained working set

частые GC + высокая суммарная pause time
→ memory pressure / allocation pressure

Old Gen близко к максимуму длительное время
→ риск OOM

#### CPU

Типичные метрики:

process_cpu_usage
system_cpu_usage
system_cpu_count

Смотрим не одиночный пик, а устойчивую загрузку.

Интерпретация:

CPU 20–50%
→ обычно есть запас

CPU 70–80% длительно под нормальной нагрузкой
→ ограниченный запас

CPU около 100% + растёт latency/queue
→ CPU bottleneck, scaling может помочь

#### Threads

Типичные метрики:

jvm_threads_live_threads
jvm_threads_daemon_threads
jvm_threads_peak_threads

И отдельно важны thread pools сервера:

tomcat_threads_busy_threads
tomcat_threads_current_threads
tomcat_threads_config_max_threads

Интерпретация:

busy близко к max
+ запросы ждут
+ latency растёт
→ saturation HTTP thread pool

threads постоянно растут и не возвращаются
→ вероятная thread leak

много threads, но CPU низкий
→ потоки могут ждать DB/network/locks

#### HikariCP / PostgreSQL connections

Типичные метрики:

hikaricp_connections_active
hikaricp_connections_idle
hikaricp_connections_pending
hikaricp_connections_max
hikaricp_connections_timeout_total

Наиболее тревожное:

active ≈ max
pending > 0
timeouts растут

Это значит, что запросы ждут свободное соединение.

Но решение не всегда “увеличить pool”:

slow SQL
long transactions
connection leak
слишком много instance × pool size
ограничение PostgreSQL max_connections

#### Kafka

Типичные метрики:

consumer lag
records consumed/sec
records produced/sec
record error rate
request latency
consumer rebalance count

Самая важная consumer-метрика — lag:

Интерпретация:

lag временно вырос и быстро уменьшился
→ допустимый burst

lag постоянно растёт
→ consumer обрабатывает медленнее producer

CPU consumer низкий, lag растёт
→ ожидание DB/API/locks или мало partitions

CPU высокий, lag растёт
→ возможно нужно масштабирование

replicas больше partitions
→ лишние replicas простаивают

#### RabbitMQ

На уровне приложения полезны:

publish count/errors
listener processing duration
listener failures
retries
DLQ count

На уровне брокера добавить exporter и посмотреть:

queue depth
ready messages
unacked messages
publish rate
deliver/ack rate
consumer count
memory/disk alarms

Интерпретация:

ready растёт
→ producers быстрее consumers

unacked растёт
→ consumers взяли сообщения, но долго не ack

DLQ растёт
→ не transient overload, а обработка систематически ломается

#### Redis

Полезны:

cache hits
cache misses
command latency
connections
evictions
memory usage

Ключевой показатель:

hit ratio = hits / (hits + misses)

Но высокий hit ratio сам по себе не гарантирует пользу. Надо видеть, снизилась ли latency и нагрузка на БД.

#### Business metrics

Технических метрик недостаточно. Для проекта надо добавить свои:

orders_created_total
outbox_events_published_total
outbox_events_failed_total
inbox_duplicates_total
notifications_processed_total
notifications_failed_total

И таймеры:

order_creation_duration
outbox_publish_duration
notification_processing_duration

Такие метрики отвечают уже на бизнес-вопросы:

Заказы создаются?
События застревают?
Какой процент уведомлений не обработан?
Сколько дублей было отфильтровано?

#### Когда масштабировать

Правильное решение нельзя принимать по одной метрике.

Масштабирование приложения имеет смысл, когда одновременно:

нагрузка растёт
latency растёт
CPU или worker/thread utilization высокая
очередь/lag растёт
downstream ещё имеет запас
Масштабирование не поможет, если:
БД уже исчерпала connections
SQL медленный
Redis/OpenSearch/Rabbit тормозит
внешний API отвечает медленно
есть lock contention
Kafka partitions меньше replicas
memory leak

Prometheus полезен именно потому, что хранит временные ряды и позволяет сопоставлять эти показатели, а не смотреть отдельные снимки. Он использует dimensional model с именем метрики и labels, а PromQL позволяет объединять и анализировать ряды.
