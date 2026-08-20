# payment-service CI/CD

This workflow builds, publishes and promotes only `payment-service`.

## Workflow

```text
.github/workflows/payment-service.yml
```

GitHub Actions does not have Jenkins-style folders for workflows. The practical
replacement is clear workflow naming. This project uses:

- `Codespaces Cluster Setup` for Terraform/k3d/GitOps bootstrap;
- `payment-service` for the service build/publish/promote flow.

## Flow

1. A pull request is merged into `main`.
2. If the change touches `services/payment-service/**` or shared Gradle files,
   GitHub starts the `payment-service` workflow.
3. The workflow runs Gradle tests and `bootJar` for `payment-service`.
4. The workflow builds and pushes the Docker image to GHCR with:
   - immutable commit SHA tag;
   - moving `main` tag.
5. The workflow updates `infra/services/values.yaml` with the immutable image.
6. The workflow commits that GitOps value change directly to `main`.
7. Argo CD sees the Git change and reconciles the running service.

The final commit is intentionally limited to one GitOps value:

```text
components.paymentService.image
```

## Direct Commit Permissions

Direct commits to `main` can be blocked by branch protection. Use one of these
options:

- allow GitHub Actions to bypass the ruleset for this repository;
- create a fine-grained personal access token and save it as
  `GITOPS_PUSH_TOKEN`;
- keep branch protection strict and return to promotion pull requests.

For this learning project, `GITOPS_PUSH_TOKEN` is the most explicit option when
branch protection blocks `GITHUB_TOKEN`.

The workflow checkout step uses:

```text
secrets.GITOPS_PUSH_TOKEN || github.token
```

So it works with the default token first, but can use your explicit token when
GitHub rules require it.

## Image Names

Images are published as:

```text
ghcr.io/<owner>/<repository>/payment-service:<git-sha>
ghcr.io/<owner>/<repository>/payment-service:main
```

Kubernetes should deploy the immutable `<git-sha>` reference stored in
`infra/services/values.yaml`. The moving `main` tag is only a convenience tag
for quick manual inspection.

## Verify

1. Start the Codespaces runner:

```bash
make github-runner-start
```

2. Bootstrap the local cluster:

```text
GitHub -> Actions -> Codespaces Cluster Setup -> Run workflow
mode = apply
```

3. Merge a pull request that changes `services/payment-service/**`.

4. Check the workflow result:

```text
GitHub -> Actions -> payment-service
```

5. Check the GitOps image value:

```bash
grep -n "paymentService:" -A 8 infra/services/values.yaml
```

6. Check Kubernetes:

```bash
kubectl get applications -n argocd
kubectl get pods -n resilient-orders
kubectl get deploy payment-service -n resilient-orders \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

7. Test through Gateway:

```bash
curl -i http://payment.localhost:8080/actuator/health
curl -i http://payment.localhost:8080/actuator/prometheus
```
