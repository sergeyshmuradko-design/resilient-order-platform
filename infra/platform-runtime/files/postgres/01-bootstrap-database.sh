#!/bin/sh
set -eu

psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set=postgres_exporter_user="$POSTGRES_EXPORTER_USER" \
  --set=postgres_exporter_password="$POSTGRES_EXPORTER_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'postgres_exporter_user', :'postgres_exporter_password')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = :'postgres_exporter_user')
\gexec

SELECT format('ALTER ROLE %I WITH PASSWORD %L', :'postgres_exporter_user', :'postgres_exporter_password')
\gexec

SELECT format('GRANT pg_monitor TO %I', :'postgres_exporter_user')
\gexec

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SQL
