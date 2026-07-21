#!/usr/bin/env bash
set -euo pipefail

# Этот скрипт выполняется official postgres image только при первом старте
# на пустом volume. Здесь создаётся инфраструктурный слой БД:
# роли, схемы и права. Таблицы создают уже Flyway-миграции сервисов.
psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set=postgres_exporter_user="$POSTGRES_EXPORTER_USER" \
  --set=postgres_exporter_password="$POSTGRES_EXPORTER_PASSWORD" \
  --set=order_owner_user="$ORDER_SERVICE_DB_OWNER_USER" \
  --set=order_owner_password="$ORDER_SERVICE_DB_OWNER_PASSWORD" \
  --set=order_app_user="$ORDER_SERVICE_DB_USER" \
  --set=order_app_password="$ORDER_SERVICE_DB_PASSWORD" \
  --set=notification_owner_user="$NOTIFICATION_SERVICE_DB_OWNER_USER" \
  --set=notification_owner_password="$NOTIFICATION_SERVICE_DB_OWNER_PASSWORD" \
  --set=notification_app_user="$NOTIFICATION_SERVICE_DB_USER" \
  --set=notification_app_password="$NOTIFICATION_SERVICE_DB_PASSWORD" <<'SQL'
-- Роль postgres_exporter нужна только для чтения стандартных PostgreSQL метрик.
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'postgres_exporter_user', :'postgres_exporter_password')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = :'postgres_exporter_user')
\gexec

-- Owner-роли запускают Flyway и владеют объектами схемы.
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'order_owner_user', :'order_owner_password')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = :'order_owner_user')
\gexec

-- App-роли используются приложениями в runtime и не должны владеть таблицами.
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'order_app_user', :'order_app_password')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = :'order_app_user')
\gexec

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'notification_owner_user', :'notification_owner_password')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = :'notification_owner_user')
\gexec

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'notification_app_user', :'notification_app_password')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = :'notification_app_user')
\gexec

-- Каждому микросервису выделена своя schema. Это отделяет ownership таблиц
-- даже если несколько сервисов пока живут в одной физической базе.
SELECT format('CREATE SCHEMA IF NOT EXISTS order_service AUTHORIZATION %I', :'order_owner_user')
\gexec

SELECT format('CREATE SCHEMA IF NOT EXISTS notification_service AUTHORIZATION %I', :'notification_owner_user')
\gexec

-- Расширение собирает статистику по SQL-запросам: calls, total time, mean time,
-- rows, shared blocks и temp I/O. Само shared_preload_libraries включается
-- через command в docker-compose.yml, а extension создаётся внутри конкретной базы.
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- CONNECT разрешает ролям подключаться к базе. Доступ к таблицам выдаётся отдельно.
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), :'postgres_exporter_user')
\gexec

SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), :'order_owner_user')
\gexec

SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), :'order_app_user')
\gexec

SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), :'notification_owner_user')
\gexec

SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), :'notification_app_user')
\gexec

SELECT format('GRANT pg_monitor TO %I', :'postgres_exporter_user')
\gexec

-- USAGE даёт runtime-роли право искать объекты внутри своей schema.
SELECT format('GRANT USAGE ON SCHEMA order_service TO %I', :'order_app_user')
\gexec

SELECT format('GRANT USAGE ON SCHEMA notification_service TO %I', :'notification_app_user')
\gexec

-- Default privileges нужны, чтобы таблицы/sequence, созданные Flyway owner-ролью,
-- автоматически становились доступными runtime app-роли.
SELECT format(
    'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA order_service GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I',
    :'order_owner_user',
    :'order_app_user'
)
\gexec

SELECT format(
    'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA order_service GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO %I',
    :'order_owner_user',
    :'order_app_user'
)
\gexec

SELECT format(
    'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA notification_service GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I',
    :'notification_owner_user',
    :'notification_app_user'
)
\gexec

SELECT format(
    'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA notification_service GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO %I',
    :'notification_owner_user',
    :'notification_app_user'
)
\gexec
SQL
