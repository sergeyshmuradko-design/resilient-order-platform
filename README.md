# resilient-order-platform
curl -X POST http://localhost:8081/orders -H "Content-Type: application/json" -H "X-Correlation-Id: TEST-12345" -d '{"customerId":"CUST-1","productId":"PROD-1","quantity":2}'
{"orderId":"eaaa6caf-5836-40bf-82a0-2563faec8d59","customerId":"CUST-1","productId":"PROD-1","quantity":2,"status":"CREATED","createdAt":"2026-05-24T18:31:49.317713148Z"}

curl -X POST http://localhost:8081/orders -H "Content-Type: application/json" -d '{"customerId":"CUST-1","productId":"PROD-1","quantity":2}'
{"orderId":"eaaa6caf-5836-40bf-82a0-2563faec8d59","customerId":"CUST-1","productId":"PROD-1","quantity":2,"status":"CREATED","createdAt":"2026-05-24T18:31:49.317713148Z"}

mkdir -p services/order-service/src/main/java/com/example/orderservice
touch services/order-service/build.gradle

docker compose up -d postgres
docker ps
docker exec -it resilient-orders-postgres psql -U orders_user -d orders_db
\q
docker compose stop postgres

./gradlew :services:order-service:clean :services:order-servic
e:build --refresh-dependencies

http://127.0.0.1:8081/swagger-ui/index.html

git status
git add .
git commit -m ""
git push

if we remove transactional from saveOrder would it be the whole transaction for all methods?

for i in {1..5}; do
  curl -X POST http://localhost:8081/orders \
    -H "Content-Type: application/json" \
    -H "X-Correlation-Id: DB-POOL-$i" \
    -d "{\"customerId\":\"CUST-$i\",\"productId\":\"PROD-1\",\"quantity\":2}" &
done
wait

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