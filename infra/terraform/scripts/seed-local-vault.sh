#!/usr/bin/env bash
set -euo pipefail

# Writes application secrets from local .env into the in-cluster Vault dev
# server. This is the local replacement for a future OCI Vault / cloud secret
# manager integration.

env_file="${1:?Usage: seed-local-vault.sh <env-file> <platform-namespace>}"
platform_namespace="${2:?platform namespace is required}"

if [ ! -f "${env_file}" ]; then
  echo "Missing ${env_file}. Create it from .env.example before running Terraform." >&2
  exit 1
fi

set -a
. "${env_file}"
set +a

: "${VAULT_DEV_ROOT_TOKEN_ID:?VAULT_DEV_ROOT_TOKEN_ID must be set in ${env_file}}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD must be set in ${env_file}}"
: "${POSTGRES_EXPORTER_PASSWORD:?POSTGRES_EXPORTER_PASSWORD must be set in ${env_file}}"
: "${ORDER_SERVICE_DB_OWNER_PASSWORD:?ORDER_SERVICE_DB_OWNER_PASSWORD must be set in ${env_file}}"
: "${ORDER_SERVICE_DB_PASSWORD:?ORDER_SERVICE_DB_PASSWORD must be set in ${env_file}}"
: "${NOTIFICATION_SERVICE_DB_OWNER_PASSWORD:?NOTIFICATION_SERVICE_DB_OWNER_PASSWORD must be set in ${env_file}}"
: "${NOTIFICATION_SERVICE_DB_PASSWORD:?NOTIFICATION_SERVICE_DB_PASSWORD must be set in ${env_file}}"
: "${JWT_SECRET:?JWT_SECRET must be set in ${env_file}}"
: "${RABBITMQ_ADMIN_USERNAME:?RABBITMQ_ADMIN_USERNAME must be set in ${env_file}}"
: "${RABBITMQ_ADMIN_PASSWORD:?RABBITMQ_ADMIN_PASSWORD must be set in ${env_file}}"
: "${ORDER_SERVICE_RABBITMQ_USERNAME:?ORDER_SERVICE_RABBITMQ_USERNAME must be set in ${env_file}}"
: "${ORDER_SERVICE_RABBITMQ_PASSWORD:?ORDER_SERVICE_RABBITMQ_PASSWORD must be set in ${env_file}}"
: "${NOTIFICATION_SERVICE_RABBITMQ_USERNAME:?NOTIFICATION_SERVICE_RABBITMQ_USERNAME must be set in ${env_file}}"
: "${NOTIFICATION_SERVICE_RABBITMQ_PASSWORD:?NOTIFICATION_SERVICE_RABBITMQ_PASSWORD must be set in ${env_file}}"
: "${GRAFANA_ADMIN_USER:?GRAFANA_ADMIN_USER must be set in ${env_file}}"
: "${GRAFANA_ADMIN_PASSWORD:?GRAFANA_ADMIN_PASSWORD must be set in ${env_file}}"
: "${ORDER_SERVICE_ADMIN_USERNAME:?ORDER_SERVICE_ADMIN_USERNAME must be set in ${env_file}}"
: "${ORDER_SERVICE_ADMIN_PASSWORD:?ORDER_SERVICE_ADMIN_PASSWORD must be set in ${env_file}}"
: "${ORDER_SERVICE_USER_USERNAME:?ORDER_SERVICE_USER_USERNAME must be set in ${env_file}}"
: "${ORDER_SERVICE_USER_PASSWORD:?ORDER_SERVICE_USER_PASSWORD must be set in ${env_file}}"

echo "Waiting for Vault Deployment to be created by Argo CD..."
for _ in $(seq 1 60); do
  if kubectl get deployment/vault --namespace "${platform_namespace}" >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

kubectl get deployment/vault --namespace "${platform_namespace}" >/dev/null

echo "Waiting for Vault Deployment to become available..."
kubectl wait deployment/vault \
  --namespace "${platform_namespace}" \
  --for=condition=Available \
  --timeout=5m

echo "Writing local application secrets to Vault KV..."
kubectl exec --namespace "${platform_namespace}" deploy/vault -- \
  env VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN="${VAULT_DEV_ROOT_TOKEN_ID}" \
  vault kv put secret/resilient-orders \
    POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
    POSTGRES_EXPORTER_PASSWORD="${POSTGRES_EXPORTER_PASSWORD}" \
    ORDER_SERVICE_DB_OWNER_PASSWORD="${ORDER_SERVICE_DB_OWNER_PASSWORD}" \
    ORDER_SERVICE_DB_PASSWORD="${ORDER_SERVICE_DB_PASSWORD}" \
    NOTIFICATION_SERVICE_DB_OWNER_PASSWORD="${NOTIFICATION_SERVICE_DB_OWNER_PASSWORD}" \
    NOTIFICATION_SERVICE_DB_PASSWORD="${NOTIFICATION_SERVICE_DB_PASSWORD}" \
    JWT_SECRET="${JWT_SECRET}" \
    RABBITMQ_ADMIN_USERNAME="${RABBITMQ_ADMIN_USERNAME}" \
    RABBITMQ_ADMIN_PASSWORD="${RABBITMQ_ADMIN_PASSWORD}" \
    ORDER_SERVICE_RABBITMQ_USERNAME="${ORDER_SERVICE_RABBITMQ_USERNAME}" \
    ORDER_SERVICE_RABBITMQ_PASSWORD="${ORDER_SERVICE_RABBITMQ_PASSWORD}" \
    NOTIFICATION_SERVICE_RABBITMQ_USERNAME="${NOTIFICATION_SERVICE_RABBITMQ_USERNAME}" \
    NOTIFICATION_SERVICE_RABBITMQ_PASSWORD="${NOTIFICATION_SERVICE_RABBITMQ_PASSWORD}" \
    GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER}" \
    GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD}" \
    ORDER_SERVICE_ADMIN_USERNAME="${ORDER_SERVICE_ADMIN_USERNAME}" \
    ORDER_SERVICE_ADMIN_PASSWORD="${ORDER_SERVICE_ADMIN_PASSWORD}" \
    ORDER_SERVICE_USER_USERNAME="${ORDER_SERVICE_USER_USERNAME}" \
    ORDER_SERVICE_USER_PASSWORD="${ORDER_SERVICE_USER_PASSWORD}"
