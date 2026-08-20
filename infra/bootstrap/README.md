# GitOps Bootstrap

This chart is the small handoff between Terraform and Argo CD.

Terraform installs Argo CD first, then installs this chart as a Helm release.
The chart creates:

- the `resilient-orders-root` AppProject;
- the `resilient-orders-root` Application pointing to `infra/root`.

After that, Argo CD owns the rest of the GitOps tree, including the
third-party operators that used to be individual Terraform Helm releases:

```text
infra/root
  -> platform operators and CRDs
  -> infra/platform-system
  -> infra/platform-runtime
  -> infra/services
```

Keeping this handoff as a Helm release gives Terraform a clean destroy order:

```text
destroy bootstrap release -> Argo CD prunes child apps -> destroy Argo CD
```

That is why the workflow does not need a separate manual `kubectl delete
application resilient-orders-root` step.
