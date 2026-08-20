#!/bin/sh
set -eu

psql -v ON_ERROR_STOP=1 \
  --host "$POSTGRES_HOST" \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" <<-SQL
{{- range .Values.database.services }}
  SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', {{ printf "'$%s'" .ownerRole.configKey }}, {{ printf "'$%s'" .ownerRole.passwordSecretKey }})
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = {{ printf "'$%s'" .ownerRole.configKey }}) \gexec
  SELECT format('ALTER ROLE %I WITH PASSWORD %L', {{ printf "'$%s'" .ownerRole.configKey }}, {{ printf "'$%s'" .ownerRole.passwordSecretKey }}) \gexec

  SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', {{ printf "'$%s'" .appRole.configKey }}, {{ printf "'$%s'" .appRole.passwordSecretKey }})
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = {{ printf "'$%s'" .appRole.configKey }}) \gexec
  SELECT format('ALTER ROLE %I WITH PASSWORD %L', {{ printf "'$%s'" .appRole.configKey }}, {{ printf "'$%s'" .appRole.passwordSecretKey }}) \gexec

  CREATE SCHEMA IF NOT EXISTS {{ .schema }} AUTHORIZATION {{ printf "\"$%s\"" .ownerRole.configKey }};

  GRANT CONNECT ON DATABASE "$POSTGRES_DB" TO {{ printf "\"$%s\"" .appRole.configKey }};
  GRANT USAGE ON SCHEMA {{ .schema }} TO {{ printf "\"$%s\"" .appRole.configKey }};

  ALTER DEFAULT PRIVILEGES FOR ROLE {{ printf "\"$%s\"" .ownerRole.configKey }}
    IN SCHEMA {{ .schema }}
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO {{ printf "\"$%s\"" .appRole.configKey }};

  ALTER DEFAULT PRIVILEGES FOR ROLE {{ printf "\"$%s\"" .ownerRole.configKey }}
    IN SCHEMA {{ .schema }}
    GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO {{ printf "\"$%s\"" .appRole.configKey }};
{{- end }}
SQL
