variable "k3d_cluster_name" {
  description = "Name of the local k3d cluster used as the lightweight Kubernetes runtime."
  type        = string
  default     = "resilient-orders"
}

variable "k3d_http_port" {
  description = "Host port mapped to the k3d load balancer HTTP port. Gateway/Ingress can use it later."
  type        = number
  default     = 8080
}
