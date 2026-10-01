#!/usr/bin/env bash
# One desired-state commit. Argo CD, not this script, orders resource deletion.
set -euo pipefail
: "${COMPONENT_INPUTS:?Missing workflow choices}" "${TARGET_BRANCH:?Missing watched branch}"
values=infra/root/values.yaml
root=resilient-orders-root
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

yq -o=json '.' "$values" | jq --argjson choices "$COMPONENT_INPUTS" \
  '{current:{selection}, choices:$choices}' \
  | jq -f infra/github-actions/selection-plan.jq > "$work/plan.json"

# Strimzi is currently an operator-only switch. Kafka resources are not selected
# by this workflow, so refuse removal if something outside selection needs it.
if jq -e '.before.enable_strimzi and (.target.enable_strimzi | not)' "$work/plan.json" >/dev/null; then
  resources="$(kubectl api-resources --api-group=kafka.strimzi.io --verbs=list -o name)"
  while IFS= read -r resource; do
    [ -n "$resource" ] || continue
    objects="$(kubectl get "$resource" --all-namespaces -o name)"
    [ -z "$objects" ] || { echo "::error::Remove $resource resources before disabling Strimzi: $objects"; exit 1; }
  done <<<"$resources"
fi

summary="$(jq -r '"| Component | Before (Git) | Choice | Target (Git) |", "|---|---|---|---|",
  ((.before | keys[]) as $key | "| \($key) | \(.before[$key]) | \(.requested[$key]) | \(.target[$key]) |")' "$work/plan.json")"
printf '%s\n' "$summary"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then printf '%s\n' "$summary" >> "$GITHUB_STEP_SUMMARY"; fi

if jq -e '.changed' "$work/plan.json" >/dev/null; then
  export SELECTION_PLAN_FILE="$work/plan.json"
  yq -i '.selection = load(strenv(SELECTION_PLAN_FILE)).target' "$values"
  helm lint infra/root
  helm template resilient-orders-root infra/root >/dev/null
  git add "$values"
  git commit -m "Configure platform components"
  git pull --rebase origin "$TARGET_BRANCH"
  # Do not overwrite a concurrent edit of the same desired state.
  yq -o=json '.selection' "$values" \
    | jq -e --slurpfile plan "$work/plan.json" '. == $plan[0].target' >/dev/null
  git push origin "HEAD:$TARGET_BRANCH"
else
  echo 'Selection already matches. No commit or reinstall; checking Argo CD.'
fi

revision="$(git rev-parse HEAD)"
kubectl -n argocd annotate application "$root" argocd.argoproj.io/refresh=hard --overwrite
# A successful sync includes foreground pruning of removed child Applications.
# Timeout reports failure; it never strips a finalizer or removes an operator.
kubectl -n argocd wait "application/$root" --for=jsonpath='{.status.sync.revision}'="$revision" --timeout=600s
kubectl -n argocd wait "application/$root" --for=jsonpath='{.status.sync.status}'=Synced --timeout=600s
kubectl -n argocd wait "application/$root" --for=jsonpath='{.status.health.status}'=Healthy --timeout=600s
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  printf '\nArgo CD reconciled the requested Git selection successfully.\n' >> "$GITHUB_STEP_SUMMARY"
fi
