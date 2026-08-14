#!/usr/bin/env bash
set -euo pipefail

# Creates the minimum local bootstrap Secrets needed by Vault dev mode and
# External Secrets Operator.
#
# Why this is a script and not kubernetes_secret in Terraform:
# Terraform state would store Secret values. For local training that may be
# acceptable, but avoiding secret values in terraform.tfstate is a better habit.

env_file="${1:?Usage: create-local-vault-token-secrets.sh <env-file> <platform-namespace> <eso-namespace> <vault-dev-secret> <eso-token-secret>}"
platform_namespace="${2:?platform namespace is required}"
external_secrets_namespace="${3:?external-secrets namespace is required}"
vault_dev_secret="${4:?Vault dev token Secret name is required}"
eso_token_secret="${5:?ESO Vault token Secret name is required}"

if [ ! -f "${env_file}" ]; then
  echo "Missing ${env_file}. Create it from .env.example before running Terraform." >&2
  exit 1
fi

# `set -a` exports variables loaded from .env into this shell process. That lets
# kubectl read VAULT_DEV_ROOT_TOKEN_ID without committing the value to Git.
set -a
. "${env_file}"
set +a

: "${VAULT_DEV_ROOT_TOKEN_ID:?VAULT_DEV_ROOT_TOKEN_ID must be set in ${env_file}}"

kubectl create namespace "${platform_namespace}" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "${external_secrets_namespace}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic "${vault_dev_secret}" \
  --namespace "${platform_namespace}" \
  --from-literal=token="${VAULT_DEV_ROOT_TOKEN_ID}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic "${eso_token_secret}" \
  --namespace "${external_secrets_namespace}" \
  --from-literal=token="${VAULT_DEV_ROOT_TOKEN_ID}" \
  --dry-run=client -o yaml | kubectl apply -f -
