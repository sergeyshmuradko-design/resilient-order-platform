# 04 PostgreSQL Details

Dashboard for PostgreSQL 16 and `postgres_exporter`.

## Exporter configuration

```yaml
image: prometheuscommunity/postgres-exporter:v0.20.1
command:
  - "--collector.database_wraparound"
  - "--collector.long_running_transactions"
  - "--collector.stat_activity_autovacuum"
  - "--collector.statio_user_indexes"
```

Do not enable `--collector.stat_checkpointer` on PostgreSQL 16; it requires PostgreSQL 17+.

## Install

Copy both files into the repository. If the dashboards directory is provisioned, run:

```powershell
docker compose restart grafana
```

Otherwise import `04-postgresql-details.json` through Grafana.

The dashboard expects the Prometheus datasource UID to be `prometheus`. If yours differs, replace that UID in the JSON.

## Notes

- `pg_long_running_transactions = 0` is healthy.
- `pg_database_wraparound_age_datfrozenxid_seconds` is XID age despite the suffix.
- Idle development databases can legitimately show zero or no data for rates, active VACUUM, autovacuum workers, and waiting locks.
- Verify an uncertain panel against `http://localhost:9187/metrics`.
