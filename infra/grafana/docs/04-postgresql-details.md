# 04 PostgreSQL Details / Детальный мониторинг PostgreSQL

## Назначение / Purpose

RU: Dashboard диагностирует PostgreSQL 16 в Resilient Orders: таблицы, индексы, VACUUM/ANALYZE, WAL, locks, долгие транзакции и XID wraparound.

EN: This dashboard diagnoses PostgreSQL 16 in Resilient Orders: tables, indexes, VACUUM/ANALYZE, WAL, locks, long transactions, and XID wraparound.

## Compatibility

- PostgreSQL 16
- `prometheuscommunity/postgres-exporter:v0.20.1`
- Prometheus job: `postgresql`
- Prometheus datasource UID: `prometheus`

```yaml
command:
  - "--collector.database_wraparound"
  - "--collector.long_running_transactions"
  - "--collector.stat_activity_autovacuum"
  - "--collector.statio_user_indexes"
```

Do not enable `--collector.stat_checkpointer` on PostgreSQL 16.

## Что исправлено / What was fixed

- Correct Prometheus job: `postgresql`, not `postgres`.
- Correct WAL names: `pg_stat_wal_records_total`, `pg_stat_wal_fpi_total`, `pg_stat_wal_bytes_total`.
- Correct lowercase lock mode: `accessexclusivelock`.
- Event-only and idle metrics use `or vector(0)` so normal inactivity appears as zero.
- The unsupported Waiting Locks panel was removed because `pg_locks_count` has no `granted` label.
- Every panel has a Russian and English description.

## 0 versus No data

RU: `0` означает, что запрос отработал, но активности нет. `No data` после этой версии означает отсутствующую метрику, ошибку collector или несовместимое имя.

EN: `0` means the query works but there is no activity. `No data` after this revision means a missing metric, collector failure, or incompatible metric name.

## Panel guide / Описание панелей

### Exporter Up
RU: 1 — Prometheus получает `/metrics`; 0 — exporter недоступен.  
EN: 1 means Prometheus scrapes `/metrics`; 0 means exporter is unreachable.

### Last Scrape Error
RU: Норма 0. Значение 1 требует проверки логов.  
EN: Healthy value is 0. A value of 1 requires checking logs.

### Collector Health
RU: Каждый collector должен показывать 1.  
EN: Every collector should show 1.

### Long-running Transactions
RU: Ноль является нормой и подтверждает работу collector.  
EN: Zero is healthy and confirms the collector works.

### Oldest XID Age
RU: Это количество XID, а не секунды. Сравнивайте с `autovacuum_freeze_max_age`.  
EN: This is an XID count, not seconds. Compare it with `autovacuum_freeze_max_age`.

### Live Tuples
RU: Оценка живых строк, не точный `COUNT(*)`.  
EN: Estimated live rows, not an exact `COUNT(*)`.

### Dead Tuples
RU: Мёртвые версии строк, ожидающие VACUUM.  
EN: Dead row versions waiting for VACUUM.

### Tuple Changes
RU: INSERT/UPDATE/DELETE в секунду. Отсутствие нагрузки отображается как 0.  
EN: INSERT/UPDATE/DELETE per second. Idle state is displayed as 0.

### Sequential Scans/sec
RU: Последовательные сканирования; нормальны для маленьких таблиц.  
EN: Sequential scans; normal for small tables.

### Index Scans/sec
RU: Индексные сканирования. Сравнивайте с Sequential Scans.  
EN: Index scans. Compare them with Sequential Scans.

### Index Cache Hit Ratio
RU: Доля index accesses из shared buffers. На dev-базе без нагрузки может быть нестабильна.  
EN: Share of index accesses served from shared buffers. It can be unstable on an idle dev database.

### Index Blocks Hit/sec
RU: Попадания в shared buffers.  
EN: Hits in shared buffers.

### Index Blocks Read/sec
RU: Физические чтения блоков индекса.  
EN: Physical index block reads.

### Vacuum Operations
RU: Завершённые ручные VACUUM и autovacuum. Ноль может быть нормой.  
EN: Completed manual VACUUM and autovacuum operations. Zero can be normal.

### Analyze Operations
RU: Завершённые ANALYZE и autoanalyze.  
EN: Completed ANALYZE and autoanalyze operations.

### Active Autovacuum Workers
RU: Workers, активные прямо сейчас. На маленькой базе обычно 0.  
EN: Workers active right now. Usually 0 on a small database.

### Vacuum in Progress
RU: VACUUM, выполняющиеся сейчас. Progress series существуют только во время операции.  
EN: VACUUM operations running now. Progress series exist only during an operation.

### WAL Records/sec
RU: WAL records в секунду.  
EN: WAL records per second.

### WAL Full-page Images/sec
RU: Full-page images; всплески возможны после checkpoint.  
EN: Full-page images; spikes can occur after checkpoints.

### WAL Bytes/sec
RU: Скорость генерации WAL.  
EN: WAL generation throughput.

### Locks by Mode
RU: Locks по режимам. Exporter не предоставляет `granted`.  
EN: Locks by mode. The exporter does not expose `granted`.

### Access Exclusive Locks
RU: Самый конфликтный стандартный lock mode; часто связан с DDL.  
EN: The most conflicting standard lock mode; often associated with DDL.

## Audit

```powershell
powershell -ExecutionPolicy Bypass -File infra/grafana/scripts/audit-postgres-metrics.ps1
```

The result is saved to:

```text
infra/grafana/docs/04-postgresql-metric-audit.txt
```

## Install

```powershell
docker compose restart grafana
```

## Commit

```powershell
git add infra/grafana/dashboards/04-postgresql-details.json `
        infra/grafana/docs/04-postgresql-details-README.md `
        infra/grafana/scripts/audit-postgres-metrics.ps1

git commit -m "fix(observability): rebuild PostgreSQL details dashboard"
```
