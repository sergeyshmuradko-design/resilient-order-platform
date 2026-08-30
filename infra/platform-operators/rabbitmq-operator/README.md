# RabbitMQ Operators

This internal chart packages official RabbitMQ Kubernetes operator release
manifests for GitOps use.

It installs:

- RabbitMQ Cluster Operator `2.16.1`
- RabbitMQ Messaging Topology Operator `1.17.4`

Why this chart exists:

- RabbitMQ does not currently publish an official Helm chart for these
  operators.
- Argo CD works well with Helm applications, so this chart is a thin packaging
  layer around official manifests.
- Resource requests and limits are reduced for the local Codespaces/k3d setup.

The topology operator manifest uses cert-manager for webhook TLS certificates.
That keeps the rendered manifest deterministic: Helm does not generate a new
self-signed CA on every render, so Argo CD does not see false drift.

Keep the upstream manifest versions pinned in Git. When upgrading, replace the
two files under `templates/` from the RabbitMQ release artifacts and re-apply
only the local resource-limit adjustments.
