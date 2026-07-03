# resilient-order-platform

## start service
./gradlew :services:notification-service:build :services:order-service:build
./gradlew :services:order-service:clean :services:order-service:build --refresh-dependencies
docker compose up -d postgres redis rabbitmq kafka schema-registry jaeger
./gradlew :services:order-service:bootRun
./gradlew :services:notification-service:bootRun \
  --args='--server.port=8084'

## docker managing

docker compose up -d postgres redis rabbitmq kafka schema-registry jaeger
docker ps
docker exec -it resilient-orders-postgres psql -U orders_user -d orders_db
\q
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

curl -i -u user:8045d350-ef51-448c-9201-9b02d9ab0347 -X POST "http://localhost:8081/exports?status=CREATED"
curl "http://localhost:8081/exports/ee3f6d37-81e5-49c2-9d8e-95c938968715"
curl -o orders.csv "http://localhost:8081/exports/b1ac03e2-f0b0-4201-bf57-a63a071effe5/download"

for i in {1..5}; do
  curl -s -X POST "http://localhost:8081/exports?status=CREATED" &
done
wait

curl "http://localhost:8081/actuator/metrics" | grep bulkhead
curl "http://localhost:8081/actuator/metrics/resilience4j.bulkhead.available.concurrent.calls?tag=name:exportJobBulkhead"
curl "http://localhost:8081/exports/5848f984-8a8a-401a-931a-cb1ff8679521/download"

curl -i -u "user:9e548291-52d8-4efc-9396-ed7f3520beac" "http://localhost:8081/orders?customerId=CUST-1&status=CREATED"
curl -i -u "admin:admin123" "http://localhost:8081/orders?customerId=CUST-1&status=CREATED"
curl -i "http://localhost:8081/orders?customerId=CUST-1&status=CREATED"
curl http://localhost:8081/actuator/health

---

TOKEN=$(curl -s -X POST http://localhost:8081/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' \
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