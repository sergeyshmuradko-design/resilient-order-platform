# Performance Test

This module contains Gatling performance tests for the resilient order platform.

The current simulation targets `order-service` and verifies a safe load-test endpoint:

```bash
GET /internal/load-test/http
```

The endpoint is available only when `order-service` runs with the `load-test` Spring profile.

## Requirements

* Java 21
* Docker Compose
* jq
* Running order-service
* Running Prometheus and Grafana if metrics correlation is needed

## Start Local Environment

From the repository root:

```bash
docker compose up -d grafana
```

Check that `order-service` is healthy:

```bash
curl http://localhost:8081/actuator/health
```

Expected response:

```bash
{"status":"UP"}
```

## Compile Gatling Classes

```bash
./gradlew --no-daemon :performance-tests:gatlingClasses
```

## Create Access Token

The simulation requires a JWT token through the `TOKEN` environment variable.

```bash
export ORDER_SERVICE_ADMIN_USERNAME="<local-admin-username>"
export ORDER_SERVICE_ADMIN_PASSWORD="<local-admin-password>"

export TOKEN=$(curl -s -X POST http://localhost:8081/auth/token \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${ORDER_SERVICE_ADMIN_USERNAME}\",\"password\":\"${ORDER_SERVICE_ADMIN_PASSWORD}\"}" \
  | jq -r '.accessToken')
```

Verify that the token was created:

```bash
echo "$TOKEN"
```

## Run Baseline HTTP Test

```bash
./gradlew --no-daemon :performance-tests:gatlingRun
```

The default simulation settings are:

```bash
BASE_URL=http://localhost:8081
TARGET_RPS=25
DELAY_MS=200
```

## Run With Custom Load

Example with lower local load:

```bash
TARGET_RPS=5 DELAY_MS=200 ./gradlew --no-daemon :performance-tests:gatlingRun
```

Example with explicit base URL:

```bash
BASE_URL=http://localhost:8081 TARGET_RPS=10 ./gradlew --no-daemon :performance-tests:gatlingRun
```

## Assertions

```bash
failed requests >= 1%
p95 response time >= 400 ms
max response time >= 2000 ms
```

## Reports

After a successful run, Gatling prints the report location:

```bash
performance-tests/build/reports/gatling/<simulation-run>/index.html
```

Open the generated `index.html` to inspect response times, percentiles, throughput, and failures.

## Notes

The Gatling Gradle task is configured with:

```bash
-Xmx256m
--add-opens=java.base/java.lang=ALL-UNNAMED
```

* The `--add-opens` JVM argument is required by Gatling internals on modern JDKs when it accesses java.lang.String internals for statistics/log writing.
* Use `--no-daemon` for local performance tests to avoid leaving Gradle daemons in memory after the run.
