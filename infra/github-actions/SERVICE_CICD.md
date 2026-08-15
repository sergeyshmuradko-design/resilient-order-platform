# Service CI/CD

This workflow is the service build and image publishing layer.

The flow is intentionally GitOps-friendly:

1. A pull request is merged into `main`.
2. GitHub Actions detects which service changed, or you choose a service
   manually through `workflow_dispatch`.
3. The workflow runs the Gradle test and `bootJar` tasks for that service.
4. The workflow builds a Docker image from `services/<service>/Dockerfile`.
5. The image is pushed to GitHub Container Registry with:
   - an immutable Git SHA tag;
   - a moving `main` tag.
6. Argo CD Image Updater watches the moving `main` tag, resolves its digest and
   updates the live Argo CD Application.

The workflow does not commit image tags back into Git. Git stores the desired
service contract and image repository; Argo CD Image Updater handles image
digest promotion inside Argo CD.

## Workflow

```text
.github/workflows/service-cicd.yml
```

Run manually:

```text
GitHub -> Actions -> Service CI/CD -> Run workflow -> service
```

Automatic run:

```text
merge pull request -> main
```

On `main`, service-specific changes build only that service. Shared Gradle or
workflow changes build all known services:

```text
payment-service
order-service
notification-service
```

## Branch Flow

Create a feature branch from a clean `main`:

```bash
git fetch origin
git switch main
git pull --ff-only origin main
git switch -c feature/service-cicd-image-updater
```

Push the branch the first time:

```bash
git push -u origin feature/service-cicd-image-updater
```

After that, plain `git push` is enough because `-u` stores the upstream branch
mapping.

Protect `main` in GitHub:

```text
Repository -> Settings -> Rules -> Rulesets
```

or:

```text
Repository -> Settings -> Branches -> Add branch protection rule
```

Recommended rules for this learning project:

- require a pull request before merging;
- require at least one approval if you want to practice review flow;
- require status checks before merge after the CI workflow exists;
- block force pushes;
- block branch deletion;
- do not allow bypassing rules unless you intentionally keep an admin escape
  hatch while learning.

In larger production setups this is often split into several repositories:
application source, GitOps manifests and platform/IaC. Keeping this project as
one repository is still a reasonable learning monorepo; the folder split already
shows the ownership boundaries.

## GitHub Actions Bot Email

The old image-promotion workflow used:

```text
41898282+github-actions[bot]@users.noreply.github.com
```

That is GitHub's standard noreply identity for commits made by the Actions bot.
It is not a personal mailbox. The current workflow no longer commits image tag
changes, so it does not need `git config user.email` at all.

## Image Names

Images are published as:

```text
ghcr.io/<owner>/<repository>/<service>:<git-sha>
ghcr.io/<owner>/<repository>/<service>:main
```

For the current first slice, Argo CD Image Updater tracks:

```text
ghcr.io/<owner>/<repository>/payment-service:main
```

with the `digest` strategy. That means Kubernetes can deploy the exact digest
behind the mutable `main` tag without storing every new SHA tag in Git.

GitHub Container Registry can create the first package as private. For the
lightweight Codespaces path, either make the package public in GitHub UI or add
an image pull Secret and set `imagePullSecrets` in the app chart values. Public
GitHub Packages usage is free; private package storage and transfer are
quota-based.

## Argo CD

Terraform creates:

```text
resilient-orders-platform -> infra/helm/admin
resilient-orders-app      -> infra/helm/app
```

The app Application uses:

```text
infra/helm/app/values-payment-service-gitops.yaml
```

That file enables `payment-service` and points it at the GHCR `:main` tag.
Argo CD Image Updater then updates only the live Argo CD Application image
parameter. It does not write to this repository.

## Verify

1. Start the Codespaces runner:

```bash
make github-runner-start
```

2. Run bootstrap:

```text
GitHub -> Actions -> GitOps Bootstrap Codespaces
apply = true
destroy = false
```

3. Run service CI/CD:

```text
GitHub -> Actions -> Service CI/CD -> Run workflow -> payment-service
```

4. Watch Argo CD:

```text
http://argocd.localhost:8080
```

5. Check Kubernetes:

```bash
kubectl get applications -n argocd
kubectl get pods -n argocd
kubectl get pods -n resilient-orders
kubectl get deploy payment-service -n resilient-orders
kubectl get deploy payment-service -n resilient-orders \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

6. Check Argo CD Image Updater logs:

```bash
kubectl logs -n argocd deploy/argocd-image-updater --tail=80
```

7. Test payment-service through Gateway:

```bash
curl -i http://payment.localhost:8080/actuator/health
curl -i http://payment.localhost:8080/actuator/prometheus
```

Swagger URLs use the same Gateway host if the service includes SpringDoc:

```text
http://payment.localhost:8080/swagger-ui/index.html
http://payment.localhost:8080/v3/api-docs
```

The current payment-service exposes Actuator and Prometheus. Swagger requires a
SpringDoc dependency in that service.

## Cleanup

Destroy the local cluster:

```text
GitHub -> Actions -> GitOps Bootstrap Codespaces
apply = true
destroy = true
```

After a successful destroy, the runner start script prunes `.local/github-runner`
working data automatically. You can also run:

```bash
make github-runner-prune
```
