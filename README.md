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

-------------

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