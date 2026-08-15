#!/usr/bin/env bash
set -euo pipefail

# Local destroy helper for the Codespaces GitOps bootstrap.
#
# Terraform removes Helm releases and namespaces during destroy. In a small
# local cluster, controllers can disappear before their Custom Resources finish
# finalizing. The most common case is ExternalSecret:
#
#   ExternalSecret -> finalizer waits for External Secrets Operator
#   External Secrets Operator -> already removed by Helm/Terraform
#   Namespace -> stuck in Terminating
#
# This script removes only known GitOps/operator finalizers before Terraform
# destroy starts. It is intentionally narrow and idempotent: missing CRDs,
# namespaces, or resources are treated as already clean.

patch_namespaced_finalizers() {
  local namespace="${1}"
  local resource_type="${2}"
  local resource_names

  resource_names="$(kubectl get "${resource_type}" \
    --namespace "${namespace}" \
    --output name 2>/dev/null || true)"

  while IFS= read -r resource_name; do
    [ -n "${resource_name}" ] || continue
    echo "Removing finalizers from ${resource_name} in namespace ${namespace}"
    kubectl patch "${resource_name}" \
      --namespace "${namespace}" \
      --type merge \
      --patch '{"metadata":{"finalizers":[]}}' >/dev/null 2>&1 || true
  done <<< "${resource_names}"
}

patch_cluster_finalizers() {
  local resource_type="${1}"
  local resource_names

  resource_names="$(kubectl get "${resource_type}" \
    --output name 2>/dev/null || true)"

  while IFS= read -r resource_name; do
    [ -n "${resource_name}" ] || continue
    echo "Removing finalizers from cluster resource ${resource_name}"
    kubectl patch "${resource_name}" \
      --type merge \
      --patch '{"metadata":{"finalizers":[]}}' >/dev/null 2>&1 || true
  done <<< "${resource_names}"
}

for namespace in resilient-orders-platform resilient-orders argocd; do
  patch_namespaced_finalizers "${namespace}" "externalsecrets.external-secrets.io"
  patch_namespaced_finalizers "${namespace}" "secretstores.external-secrets.io"
  patch_namespaced_finalizers "${namespace}" "applications.argoproj.io"
  patch_namespaced_finalizers "${namespace}" "applicationsets.argoproj.io"
done

patch_cluster_finalizers "clustersecretstores.external-secrets.io"

echo "Pre-destroy Kubernetes cleanup completed."
