variable "kubeconfig_path" {
  description = "Path to kubeconfig used by Terraform, Helm and kubectl."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubernetes context. For Codespaces the default is k3d-resilient-orders."
  type        = string
  default     = "k3d-resilient-orders"
}

variable "repository_url" {
  description = "Git repository URL that Argo CD should sync from."
  type        = string
  default     = ""
}

variable "container_image_prefix" {
  description = "Container registry prefix for service images, without the service name. Example: ghcr.io/owner/repository."
  type        = string
  default     = "ghcr.io/sergeyshmuradko-design/resilient-order-platform"
}

variable "target_revision" {
  description = "Git revision watched by Argo CD. Use main locally; use a release branch/tag later."
  type        = string
  default     = "main"
}

variable "platform_namespace" {
  description = "Namespace for admin-owned platform components such as PostgreSQL."
  type        = string
  default     = "resilient-orders-platform"
}

variable "application_namespace" {
  description = "Namespace reserved for application workloads."
  type        = string
  default     = "resilient-orders"
}

variable "external_secrets_namespace" {
  description = "Namespace where External Secrets Operator runs."
  type        = string
  default     = "external-secrets"
}

variable "argocd_namespace" {
  description = "Namespace where Argo CD runs."
  type        = string
  default     = "argocd"
}

variable "strimzi_namespace" {
  description = "Namespace where the Strimzi Kafka Operator Argo Application deploys."
  type        = string
  default     = "strimzi-system"
}

variable "nginx_gateway_namespace" {
  description = "Namespace where the NGINX Gateway Fabric Argo Application deploys."
  type        = string
  default     = "nginx-gateway"
}

variable "rabbitmq_operator_namespace" {
  description = "Namespace where RabbitMQ Cluster Operator and Messaging Topology Operator deploy."
  type        = string
  default     = "rabbitmq-system"
}

variable "enable_argocd_application" {
  description = "Create the root Argo CD Application that syncs the GitOps app-of-apps chart."
  type        = bool
  default     = true
}

variable "infisical_host_api" {
  description = "Infisical API endpoint used by External Secrets Operator."
  type        = string
  default     = "https://app.infisical.com"
}

variable "infisical_project_slug" {
  description = "Infisical project slug that contains resilient-order-platform secrets."
  type        = string
  default     = "replace-me"
}

variable "infisical_environment_slug" {
  description = "Infisical environment slug, for example dev, staging or prod."
  type        = string
  default     = "dev"
}

variable "infisical_secrets_path" {
  description = "Infisical secrets path where the expected application keys are stored."
  type        = string
  default     = "/"
}

variable "infisical_auth_secret_name" {
  description = "Kubernetes Secret name that stores Infisical Universal Auth credentials for ESO."
  type        = string
  default     = "infisical-universal-auth"
}

variable "infisical_client_id" {
  description = "Infisical Universal Auth Client ID. Set from GitHub Actions secrets for Codespaces runs."
  type        = string
  default     = ""
  sensitive   = true
}

variable "infisical_client_secret" {
  description = "Infisical Universal Auth Client Secret. Set from GitHub Actions secrets for Codespaces runs."
  type        = string
  default     = ""
  sensitive   = true
}

variable "external_secrets_chart_version" {
  description = "External Secrets Operator Helm chart version. Pin for reproducible local/prod runs."
  type        = string
  default     = "2.8.0"
}

variable "strimzi_chart_version" {
  description = "Strimzi Kafka Operator Helm chart version."
  type        = string
  default     = "1.1.0"
}

variable "nginx_gateway_chart_version" {
  description = "NGINX Gateway Fabric Helm chart version."
  type        = string
  default     = "2.6.7"
}

variable "argocd_chart_version" {
  description = "Argo CD Helm chart version."
  type        = string
  default     = "10.1.3"
}

variable "rabbitmq_operator_chart_version" {
  description = "Bitnami RabbitMQ Cluster Operator chart version. The chart installs both Cluster Operator and Messaging Topology Operator."
  type        = string
  default     = "4.4.34"
}
