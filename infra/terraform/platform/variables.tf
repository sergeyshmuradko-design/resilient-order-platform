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

variable "target_revision" {
  description = "Git revision watched by Argo CD. Use main locally; use a release branch/tag later."
  type        = string
  default     = "main"
}

variable "local_env_file" {
  description = "Local .env file used only for Codespaces bootstrap into local Vault."
  type        = string
  default     = "../../../.env"
}

variable "platform_namespace" {
  description = "Namespace for admin-owned platform components such as Vault and PostgreSQL."
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
  description = "Namespace where Strimzi Kafka Operator runs."
  type        = string
  default     = "strimzi-system"
}

variable "nginx_gateway_namespace" {
  description = "Namespace where NGINX Gateway Fabric runs."
  type        = string
  default     = "nginx-gateway"
}

variable "enable_strimzi" {
  description = "Install Strimzi Kafka Operator. Keep it disabled in the default Codespaces slice until Kafka is tested."
  type        = bool
  default     = false
}

variable "enable_gateway_controller" {
  description = "Install Gateway API CRDs and NGINX Gateway Fabric for the future HTTP routing stage."
  type        = bool
  default     = true
}

variable "enable_local_vault_seed" {
  description = "Seed local Vault from .env after Argo CD creates the Vault Deployment."
  type        = bool
  default     = true
}

variable "enable_argocd_application" {
  description = "Create the Argo CD Application that syncs the initial PostgreSQL platform chart."
  type        = bool
  default     = true
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
