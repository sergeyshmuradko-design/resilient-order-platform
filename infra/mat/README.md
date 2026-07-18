# Eclipse Memory Analyzer

This directory contains a headless Eclipse Memory Analyzer Tool setup for parsing JVM heap dumps.

The tool is used to analyze `order-service` heap dumps generated during local diagnostics or load testing.

## Files

```text
infra/mat/Dockerfile
infra/mat/analyze-heap.sh
docker-compose.diagnostics.yml
infra/heap-dumps/
infra/heap-reports/
```

## Create Heap Dump

For automatic heap dump creation on Java heap OOM, configure `order-service` with:

```yaml
JAVA_TOOL_OPTIONS: >-
  -Xms256m
  -Xmx256m
  -XX:+HeapDumpOnOutOfMemoryError
  -XX:HeapDumpPath=/diagnostics/order-service-oom.hprof
```

Mount the diagnostics directory into the container:

```yaml
volumes:
  - ./infra/heap-dumps:/diagnostics
```

Expected output file:

```text
infra/heap-dumps/order-service-oom.hprof
```

## Analyze Heap Dump

From the repository root:

```bash
./infra/mat/analyze-heap.sh
```

By default, the script analyzes:

```text
infra/heap-dumps/order-service-oom.hprof
```

and runs the MAT suspects report:

```text
org.eclipse.mat.api:suspects
```

You can pass a custom heap dump name:

```bash
./infra/mat/analyze-heap.sh my-dump.hprof
```

You can also pass a custom MAT report type:

```bash
./infra/mat/analyze-heap.sh order-service-oom.hprof org.eclipse.mat.api:overview
```

## Output

The script creates an HTML report under:

```text
infra/heap-reports/order-service-oom/index.html
```

It also moves the generated ZIP report to:

```text
infra/heap-reports/order-service-oom_Leak_Suspects.zip
```

MAT index files remain beside the heap dump in:

```text
infra/heap-dumps/
```

These files speed up repeated analysis, but they can consume disk space.

## View Report

Start a local static file server from the repository root:

```bash
python3 -m http.server 8001
```

Open:

```text
http://localhost:8001/infra/heap-reports/order-service-oom/index.html
```

Alternatively, start the server directly from the report directory:

```bash
cd infra/heap-reports/order-service-oom
python3 -m http.server 8001
```

Open:

```text
http://localhost:8001/index.html
```

## Clean Generated Files

Remove generated MAT reports:

```bash
rm -rf infra/heap-reports/order-service-oom
rm -f infra/heap-reports/order-service-oom_Leak_Suspects.zip
```

Remove generated MAT indexes while keeping the original heap dump:

```bash
find infra/heap-dumps -type f ! -name '*.hprof' -delete
```

Remove the heap dump too, only if it is no longer needed:

```bash
rm -f infra/heap-dumps/order-service-oom.hprof
```

## Troubleshooting

If the script cannot write the report directory:

```bash
sudo chown -R $(id -u):$(id -g) infra/heap-reports
```

If the heap dump is missing, verify the file exists:

```bash
ls -lh infra/heap-dumps
```

If the MAT image needs to be rebuilt:

```bash
docker compose -f docker-compose.diagnostics.yml build mat-headless
```

## Notes

The MAT container uses Java 21 and Eclipse MAT in headless mode.
The heap configured for MAT itself is defined in `docker-compose.diagnostics.yml`:

```yaml
JAVA_TOOL_OPTIONS: "-Xms512m -Xmx2g"
```

This is the memory available to the analyzer, not the memory limit of `order-service`.