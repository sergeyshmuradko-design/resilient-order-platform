output "argocd_namespace" {
  description = "Namespace where Argo CD is installed."
  value       = var.argocd_namespace
}

output "platform_namespace" {
  description = "Namespace where the initial PostgreSQL/Vault platform slice is reconciled."
  value       = var.platform_namespace
}

output "application_namespace" {
  description = "Namespace reserved for application workloads."
  value       = var.application_namespace
}
