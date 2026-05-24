# resilient-order-platform
curl -X POST http://localhost:8081/orders -H "Content-Type: application/json" -d '{"customerId":"CUST-1","productId":"PROD-1","quantity":2}'
{"orderId":"eaaa6caf-5836-40bf-82a0-2563faec8d59","customerId":"CUST-1","productId":"PROD-1","quantity":2,"status":"CREATED","createdAt":"2026-05-24T18:31:49.317713148Z"}

curl -X POST http://localhost:8081/orders -H "Content-Type: application/json" -d '{"customerId":"CUST-1","productId":"PROD-1","quantity":2}'
{"orderId":"eaaa6caf-5836-40bf-82a0-2563faec8d59","customerId":"CUST-1","productId":"PROD-1","quantity":2,"status":"CREATED","createdAt":"2026-05-24T18:31:49.317713148Z"}

mkdir -p services/order-service/src/main/java/com/example/orderservice
touch services/order-service/build.gradle