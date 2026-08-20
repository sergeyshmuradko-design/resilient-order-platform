# Terraform owns only the bootstrap boundary:
#
# 1. Install Argo CD as the GitOps controller.
# 2. Install one small local Helm chart that creates the root Argo CD
#    Application. The root Application then owns operator Applications,
#    platform-system, platform-runtime and services from Git.
#
# Keeping Argo CD as a separate Helm release is deliberate. During destroy,
# Terraform removes the GitOps bootstrap release first while the Argo CD
# controller is still running, so Argo CD can process the root Application
# finalizer and prune child Applications before the controller itself is
# uninstalled.

resource "helm_release" "argocd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true

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
}

resource "helm_release" "gitops_bootstrap" {
  count = var.enable_argocd_application && var.repository_url != "" ? 1 : 0

  name             = "resilient-orders-bootstrap"
  chart            = "${path.module}/../../bootstrap"
  namespace        = var.argocd_namespace
  create_namespace = true

  wait    = true
  timeout = 300

  set {
    name  = "repositoryUrl"
    value = var.repository_url
  }
  set {
    name  = "targetRevision"
    value = var.target_revision
  }
  set {
    name  = "namespaces.argocd"
    value = var.argocd_namespace
  }
  set {
    name  = "namespaces.platform"
    value = var.platform_namespace
  }
  set {
    name  = "namespaces.application"
    value = var.application_namespace
  }
  set {
    name  = "namespaces.externalSecrets"
    value = var.external_secrets_namespace
  }
  set {
    name  = "namespaces.rabbitmqOperator"
    value = var.rabbitmq_operator_namespace
  }
  set {
    name  = "namespaces.nginxGateway"
    value = var.nginx_gateway_namespace
  }
  set {
    name  = "namespaces.strimzi"
    value = var.strimzi_namespace
  }
  set {
    name  = "containerImagePrefix"
    value = var.container_image_prefix
  }
  set {
    name  = "operators.externalSecrets.targetRevision"
    value = var.external_secrets_chart_version
  }
  set {
    name  = "operators.rabbitmq.targetRevision"
    value = var.rabbitmq_operator_chart_version
  }
  set {
    name  = "operators.gatewayApiCrds.targetRevision"
    value = "v${var.nginx_gateway_chart_version}"
  }
  set {
    name  = "operators.nginxGateway.targetRevision"
    value = var.nginx_gateway_chart_version
  }
  set {
    name  = "operators.strimzi.enabled"
    value = var.enable_strimzi
  }
  set {
    name  = "operators.strimzi.targetRevision"
    value = var.strimzi_chart_version
  }
  set {
    name  = "operators.externalSecrets.enabled"
    value = "true"
  }
  set {
    name  = "operators.rabbitmq.enabled"
    value = var.enable_rabbitmq_operators
  }
  set {
    name  = "operators.gatewayApiCrds.enabled"
    value = var.enable_gateway_controller
  }
  set {
    name  = "operators.nginxGateway.enabled"
    value = var.enable_gateway_controller
  }
  set {
    name  = "secrets.external.infisical.hostAPI"
    value = var.infisical_host_api
  }
  set {
    name  = "secrets.external.infisical.projectSlug"
    value = var.infisical_project_slug
  }
  set {
    name  = "secrets.external.infisical.environmentSlug"
    value = var.infisical_environment_slug
  }
  set {
    name  = "secrets.external.infisical.secretsPath"
    value = var.infisical_secrets_path
  }
  set_sensitive {
    name  = "secrets.external.infisical.clientId"
    value = var.infisical_client_id
  }
  set_sensitive {
    name  = "secrets.external.infisical.clientSecret"
    value = var.infisical_client_secret
  }
  set {
    name  = "secrets.external.infisical.authSecretName"
    value = var.infisical_auth_secret_name
  }
  set {
    name  = "secrets.external.infisical.authSecretNamespace"
    value = var.external_secrets_namespace
  }

  depends_on = [helm_release.argocd]
}
