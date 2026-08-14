output "cluster_context" {
  description = "kubectl context created for the local Codespaces k3d cluster."
  value       = "k3d-${var.k3d_cluster_name}"
}

output "cleanup_command" {
  description = "Equivalent manual cleanup command if Terraform state is unavailable."
  value       = "k3d cluster delete ${var.k3d_cluster_name}"
}
