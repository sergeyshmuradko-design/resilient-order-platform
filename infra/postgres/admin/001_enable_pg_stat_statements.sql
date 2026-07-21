-- Этот скрипт предназначен для уже существующей базы.
-- Для новой локальной базы extension создаётся init-скриптом
-- infra/postgres/init/01-bootstrap-database.sh.
--
-- Важно: перед выполнением CREATE EXTENSION Postgres должен быть запущен
-- с shared_preload_libraries=pg_stat_statements.

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
