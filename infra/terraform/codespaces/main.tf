# Codespaces owns only the disposable local Kubernetes runtime.
#
# The platform layer is intentionally separate. It can target this k3d cluster
# today and an Oracle/OKE/k3s cluster later without changing platform resources.
resource "terraform_data" "k3d_cluster" {
  input = {
    cluster_name = var.k3d_cluster_name
    http_port    = tostring(var.k3d_http_port)
  }

  triggers_replace = {
    cluster_name = var.k3d_cluster_name
    http_port    = tostring(var.k3d_http_port)
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-ec"]
    command     = <<-EOT
      if k3d cluster list ${var.k3d_cluster_name} >/dev/null 2>&1; then
        echo "k3d cluster ${var.k3d_cluster_name} already exists"
      else
        k3d cluster create ${var.k3d_cluster_name} \
          --servers 1 \
          --agents 0 \
          --port '${var.k3d_http_port}:80@loadbalancer' \
          --k3s-arg '--disable=traefik@server:0'
      fi

      kubectl config use-context k3d-${var.k3d_cluster_name}
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-ec"]
    command     = "k3d cluster delete ${self.input.cluster_name} || true"
  }
}
