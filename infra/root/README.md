# Git-owned component lifecycle

The root owns child Applications, not their internal workloads. Independently
removable components have separate Applications. Argo CD orders both sync and
foreground deletion; a workflow only commits the final desired selection.

## Selection

Workflow inputs are `keep / enable / disable`; `values.yaml -> selection`
stores booleans. Matching choices create no commit or reinstall. A retry after a
timeout waits for Argo to finish the already committed state, without another
commit. There are no intermediate shutdown states.

- PostgreSQL and Redis each have an Application.
- RabbitMQ selects cert-manager, operators, broker and topology Applications.
- Kyverno selects the operator and policies Applications.
- Each Spring service has its own Application.
- Strimzi currently selects only the operator, not Kafka or Schema Registry.
- ESO and Gateway remain part of the baseline.

## Ownership and order

| Wave | Applications | Deleted before |
| --- | --- | --- |
| 10 | order-service, notification-service | payment and infrastructure |
| 0 | payment-service | topology and infrastructure |
| -5 | RabbitMQ topology | broker |
| -10 | PostgreSQL, Redis, RabbitMQ broker, runtime extensions | base and operators |
| -15 | shared service secrets/RBAC, Kyverno policies | namespaces and operators |
| -20 | platform-system base | controllers |
| -25 | NGINX Gateway | Gateway API CRDs |
| -30 | ESO, Gateway API CRDs, RabbitMQ/Strimzi/Kyverno operators | cert-manager |
| -35 | cert-manager | AppProjects |
| -40/-50 | AppProjects | root completion |

Creation uses ascending waves; deletion uses descending waves. An Application's
foreground finalizer remains until its resources disappear. A stuck topology
resource therefore blocks broker/operator deletion, not just the workflow.

Root uses `PrunePropagationPolicy=foreground`.
Root intentionally does NOT use `PruneLast=true`:
that option collapses prune tasks into a single final wave, losing their relative
deletion order. Local component Applications also keep their internal waves.
Custom Application health waits for the current child source to become
Synced/Healthy on startup. It does not
replace finalizers during deletion. No ApplicationSet controller or Progressive
Syncs feature gate is needed for this tree.

The same three charts keep the admin/developer ownership boundaries. Their
`renderScope` selects a disjoint subset of templates per Application. This is a
chart rendering parameter, not another operator or user enable switch. Root sets
it; component settings/images/limits remain in each chart's single values file.
`renderScope: all` is for standalone rendering only. Do not install that entire
chart alongside its GitOps-managed scoped Applications.

The runtime extensions Application retains disabled-by-default Kafka, Schema
Registry, tracing and monitoring settings for later stages. Before enabling
these, review dependencies and split their lifecycle as needed. The Strimzi
disable guard refuses to remove the operator while Kafka CRs still exist.

## Full destroy

Terraform uninstalls bootstrap first and waits for its root Application finalizer.
Argo removes children in reverse waves; only then does Terraform uninstall Argo.
The workflow removes k3d last. There is no Bash child-deletion loop.

Bootstrap repository Secrets, Infisical credentials and root AppProject have
Helm's `keep` policy, because Helm otherwise removes them concurrently with root.
Platform-only destroy deliberately retains these objects; full k3d deletion
removes them. This is not a guarantee of cloud disk/snapshot cleanup.

Failure stops deletion instead of stripping finalizers. Restore the unavailable
controller/broker or correct its error, then repeat destroy. A terminating
Application cannot be "undeleted" by selecting enable.

## Upgrade from the previous grouped Applications

This changes resource ownership. Do NOT push this change to a branch watched by
an old live cluster and expect an automatic zero-downtime adoption. For this
disposable Codespaces setup:
1. Destroy the old cluster using its old workflow/revision first.
2. Commit/push the new manifests and run bootstrap apply.
3. Run platform deploy with desired choices.

For a persistent cluster, resource adoption/orphaning needs a separate reviewed
migration and backups. Do not resolve SharedResource warnings by enabling two
owners or stripping finalizers. Disabling a database/broker may affect data;
retained PVCs are not backups.

## Offline checks

```bash
helm template resilient-orders-root infra/root --set selection.enable_rabbitmq_stack=true
ruby infra/github-actions/test-selection.rb
ruby infra/github-actions/test-gitops.rb
YQ_BIN=/path/to/yq ruby infra/github-actions/test-apply-selection.rb
```

These verify rendering, non-overlapping ownership, waves and one-commit behavior.
Actual controller/finalizer behavior still requires the disposable-cluster test
in [WORKFLOW_EXPLAINED.md](../github-actions/WORKFLOW_EXPLAINED.md).
