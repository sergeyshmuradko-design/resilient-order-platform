locals {
  # Labels are intentionally boring and consistent. They make it easier to list
  # or delete all namespaces/resources that belong to this learning platform.
  common_labels = {
    "app.kubernetes.io/part-of"    = "resilient-order-platform"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

resource "kubernetes_namespace_v1" "platform" {
  metadata {
    name = var.platform_namespace
    labels = merge(local.common_labels, {
      "resilient-orders.io/gateway-routes" = "allowed"
    })
  }
}

resource "kubernetes_namespace_v1" "application" {
  metadata {
    name = var.application_namespace
    labels = merge(local.common_labels, {
      "resilient-orders.io/gateway-routes" = "allowed"
    })
  }
}

resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name   = var.external_secrets_namespace
    labels = local.common_labels
  }
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.argocd_namespace
    labels = merge(local.common_labels, {
      "resilient-orders.io/gateway-routes" = "allowed"
    })
  }
}

resource "kubernetes_namespace_v1" "strimzi" {
  count = var.enable_strimzi ? 1 : 0

  metadata {
    name   = var.strimzi_namespace
    labels = local.common_labels
  }
}

resource "kubernetes_namespace_v1" "nginx_gateway" {
  count = var.enable_gateway_controller ? 1 : 0

  metadata {
    name   = var.nginx_gateway_namespace
    labels = local.common_labels
  }
}

# The local Vault root token is created through kubectl instead of Terraform's
# kubernetes_secret resource. That keeps the token out of terraform.tfstate.
resource "terraform_data" "local_vault_token_secrets" {
  count = var.enable_local_vault_seed ? 1 : 0

  triggers_replace = {
    env_file                   = var.local_env_file
    platform_namespace         = var.platform_namespace
    external_secrets_namespace = var.external_secrets_namespace
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-ec"]
    command = join(" ", [
      "bash",
      "${path.module}/../scripts/create-local-vault-token-secrets.sh",
      var.local_env_file,
      var.platform_namespace,
      var.external_secrets_namespace,
      "vault-dev-token",
      "vault-token"
    ])
  }

  depends_on = [
    kubernetes_namespace_v1.platform,
    kubernetes_namespace_v1.external_secrets
  ]
}

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.external_secrets_chart_version
  namespace  = var.external_secrets_namespace

  wait          = true
  timeout       = 180
  recreate_pods = false

  set {
    name  = "installCRDs"
    value = "true"
  }
  set {
    name  = "resources.requests.cpu"
    value = "10m"
  }
  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }
  set {
    name  = "resources.limits.cpu"
    value = "100m"
  }
  set {
    name  = "resources.limits.memory"
    value = "128Mi"
  }
  set {
    name  = "webhook.resources.requests.cpu"
    value = "10m"
  }
  set {
    name  = "webhook.resources.requests.memory"
    value = "32Mi"
  }
  set {
    name  = "webhook.resources.limits.cpu"
    value = "100m"
  }
  set {
    name  = "webhook.resources.limits.memory"
    value = "96Mi"
  }
  set {
    name  = "certController.resources.requests.cpu"
    value = "10m"
  }
  set {
    name  = "certController.resources.requests.memory"
    value = "32Mi"
  }
  set {
    name  = "certController.resources.limits.cpu"
    value = "100m"
  }
  set {
    name  = "certController.resources.limits.memory"
    value = "96Mi"
  }

  depends_on = [kubernetes_namespace_v1.external_secrets]
}

resource "helm_release" "strimzi" {
  count = var.enable_strimzi ? 1 : 0

  name       = "strimzi-kafka-operator"
  repository = "oci://quay.io/strimzi-helm"
  chart      = "strimzi-kafka-operator"
  version    = var.strimzi_chart_version
  namespace  = var.strimzi_namespace

  wait    = true
  timeout = 240

  set {
    name  = "watchAnyNamespace"
    value = "true"
  }
  set {
    name  = "replicas"
    value = "1"
  }
  set {
    name  = "resources.requests.cpu"
    value = "25m"
  }
  set {
    name  = "resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "resources.limits.cpu"
    value = "300m"
  }
  set {
    name  = "resources.limits.memory"
    value = "384Mi"
  }

  depends_on = [kubernetes_namespace_v1.strimzi]
}

# Gateway API CRDs are Kubernetes API extensions. The controller chart does not
# own the standard CRDs, so the bootstrap layer applies them once before
# installing NGINX Gateway Fabric.
resource "terraform_data" "gateway_api_crds" {
  count = var.enable_gateway_controller ? 1 : 0

  triggers_replace = {
    nginx_gateway_chart_version = var.nginx_gateway_chart_version
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-ec"]
    command     = "kubectl kustomize 'https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v${var.nginx_gateway_chart_version}' | kubectl apply -f -"
  }
}

resource "helm_release" "nginx_gateway" {
  count = var.enable_gateway_controller ? 1 : 0

  name       = "ngf"
  repository = "oci://ghcr.io/nginx/charts"
  chart      = "nginx-gateway-fabric"
  version    = var.nginx_gateway_chart_version
  namespace  = var.nginx_gateway_namespace

  wait    = true
  timeout = 240

  set {
    name  = "nginx.service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "nginxGateway.replicaCount"
    value = "1"
  }
  set {
    name  = "nginxGateway.resources.requests.cpu"
    value = "25m"
  }
  set {
    name  = "nginxGateway.resources.requests.memory"
    value = "96Mi"
  }
  set {
    name  = "nginxGateway.resources.limits.cpu"
    value = "300m"
  }
  set {
    name  = "nginxGateway.resources.limits.memory"
    value = "256Mi"
  }

  depends_on = [
    kubernetes_namespace_v1.nginx_gateway,
    terraform_data.gateway_api_crds
  ]
}

resource "helm_release" "argocd" {
  name       = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = var.argocd_namespace

  wait    = true
  timeout = 300

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }
  set {
    name  = "dex.enabled"
    value = "false"
  }
  set {
    name  = "applicationSet.enabled"
    value = "false"
  }
  set {
    name  = "notifications.enabled"
    value = "false"
  }
  set {
    name  = "controller.resources.requests.cpu"
    value = "25m"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "controller.resources.limits.memory"
    value = "384Mi"
  }
  set {
    name  = "server.resources.requests.cpu"
    value = "25m"
  }
  set {
    name  = "server.resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "server.resources.limits.memory"
    value = "384Mi"
  }
  set {
    name  = "repoServer.resources.requests.cpu"
    value = "25m"
  }
  set {
    name  = "repoServer.resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "repoServer.resources.limits.memory"
    value = "384Mi"
  }
  set {
    name  = "redis.resources.requests.cpu"
    value = "10m"
  }
  set {
    name  = "redis.resources.requests.memory"
    value = "32Mi"
  }
  set {
    name  = "redis.resources.limits.cpu"
    value = "100m"
  }
  set {
    name  = "redis.resources.limits.memory"
    value = "96Mi"
  }

  depends_on = [kubernetes_namespace_v1.argocd]
}

resource "helm_release" "argocd_image_updater" {
  count = var.enable_argocd_image_updater ? 1 : 0

  name       = "argocd-image-updater"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-image-updater"
  version    = var.argocd_image_updater_chart_version
  namespace  = var.argocd_namespace

  wait    = true
  timeout = 180

  # The updater is intentionally scoped to the single application release used
  # in this demo and checks the registry slowly. In production this same chart
  # can watch more Applications, but local Codespaces runs should stay quiet.
  set_list {
    name = "extraArgs"
    value = [
      "--interval=10m",
      "--max-concurrent-apps=1",
      "--max-concurrent-reconciles=1",
      "--match-application-name=resilient-orders-app"
    ]
  }
  set {
    name  = "resources.requests.cpu"
    value = "10m"
  }
  set {
    name  = "resources.requests.memory"
    value = "48Mi"
  }
  set {
    name  = "resources.limits.cpu"
    value = "100m"
  }
  set {
    name  = "resources.limits.memory"
    value = "128Mi"
  }

  depends_on = [helm_release.argocd]
}

# This is the GitOps handoff: Terraform installs Argo CD, then creates one
# Argo CD Application. After that Argo CD continuously reconciles the Helm chart
# from Git instead of Terraform applying application manifests directly.
resource "terraform_data" "argocd_platform_application" {
  count = var.enable_argocd_application && var.repository_url != "" ? 1 : 0

  triggers_replace = {
    repository_url  = var.repository_url
    target_revision = var.target_revision
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-ec"]
    command     = "cat <<'YAML' | kubectl apply -f -\n${templatefile("${path.module}/../templates/resilient-orders-platform-application.yaml.tftpl", { repository_url = var.repository_url, target_revision = var.target_revision, platform_namespace = var.platform_namespace })}\nYAML"
  }

  depends_on = [
    helm_release.argocd,
    helm_release.argocd_image_updater,
    helm_release.external_secrets,
    terraform_data.local_vault_token_secrets
  ]
}

resource "terraform_data" "argocd_app_application" {
  count = var.enable_argocd_app_application && var.repository_url != "" ? 1 : 0

  triggers_replace = {
    repository_url         = var.repository_url
    target_revision        = var.target_revision
    container_image_prefix = var.container_image_prefix
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-ec"]
    command     = "cat <<'YAML' | kubectl apply -f -\n${templatefile("${path.module}/../templates/resilient-orders-app-application.yaml.tftpl", { repository_url = var.repository_url, target_revision = var.target_revision, application_namespace = var.application_namespace, container_image_prefix = var.container_image_prefix })}\nYAML"
  }

  depends_on = [
    terraform_data.argocd_platform_application
  ]
}

# Local-only seed step. In Oracle Cloud this should become OCI Vault/Secret
# Manager provisioning and this resource should be disabled.
resource "terraform_data" "local_vault_seed" {
  count = var.enable_local_vault_seed && var.enable_argocd_application && var.repository_url != "" ? 1 : 0

  triggers_replace = {
    env_file           = var.local_env_file
    platform_namespace = var.platform_namespace
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-ec"]
    command     = "bash ${path.module}/../scripts/seed-local-vault.sh ${var.local_env_file} ${var.platform_namespace}"
  }

  depends_on = [terraform_data.argocd_app_application]
}
