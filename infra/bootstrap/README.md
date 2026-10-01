# GitOps Bootstrap

Terraform installs Argo CD, then this small Helm release:
- root AppProject;
- root Application pointing to infra/root;
- OCI repository configuration and Infisical Universal Auth Secret.

Argo owns operator and component Applications. Deploy commits one final component
selection; no runtime state machine or multi-commit cleanup lives in the workflow.

## Destruction boundary

```text
Terraform uninstalls bootstrap
  -> root foreground finalizer
  -> Argo deletes child Applications in reverse waves
  -> each child waits for its managed resources
  -> root disappears
Terraform uninstalls Argo CD
Workflow destroys k3d
```

The root AppProject and repository/auth Secrets use Helm's keep policy. Helm
otherwise deletes them concurrently with root, breaking access during cleanup.
Platform-only destroy retains these small objects; full k3d deletion removes
them. The same release name can manage them on reinstall.

No script pauses root or loops over child deletions. Finalizers are never removed
automatically. A blocked cleanup stops before Terraform removes Argo CD.

See [root ownership/order](../root/README.md) and
[workflow test/upgrade procedure](../github-actions/WORKFLOW_EXPLAINED.md).
