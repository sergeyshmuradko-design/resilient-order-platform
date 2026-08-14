.PHONY: build infra-up up stop down ps config terraform-fmt terraform-codespaces-init terraform-codespaces-plan terraform-codespaces-apply terraform-codespaces-destroy terraform-platform-init terraform-platform-validate terraform-platform-plan terraform-platform-apply terraform-platform-destroy terraform-init terraform-validate terraform-plan terraform-apply terraform-destroy github-runner-start github-runner-cleanup helm-external-secrets helm-strimzi-operator helm-gateway-api-crds helm-nginx-gateway helm-operators helm-vault-token-source helm-vault-seed helm-db-provision helm-images-import helm-lint helm-template-dev helm-template-monitoring helm-template-local-expose helm-template-local-gateway helm-template-codespaces helm-template-postgres-only helm-dev helm-monitoring helm-local-expose helm-local-gateway helm-codespaces helm-platform helm-schema-registry helm-apps helm-observability helm-prod-like helm-tracing helm-load helm-delete helm-delete-all load-build load-up load-stop load-down load-config

# Compose command used for the load-test variant.
# The second file overrides only the settings that are different for load tests.
COMPOSE_LOAD_TEST = docker compose -f docker-compose.yml -f docker-compose.load-test.yml

HELM_ADMIN_RELEASE = resilient-orders-admin
HELM_APP_RELEASE = resilient-orders-app
HELM_PLATFORM_NAMESPACE = resilient-orders-platform
HELM_APP_NAMESPACE = resilient-orders
HELM_NAMESPACE = $(HELM_APP_NAMESPACE)
HELM_ADMIN_CHART = infra/helm/admin
HELM_APP_CHART = infra/helm/app
HELM_VAULT_TOKEN_SECRET_NAME = vault-token
HELM_VAULT_DEV_TOKEN_SECRET_NAME = vault-dev-token
K3D_CLUSTER = resilient-orders
STRIMZI_NAMESPACE = strimzi-system
NGINX_GATEWAY_NAMESPACE = nginx-gateway
KAFKA_CLUSTER = resilient-kafka
GATEWAY_ROUTE_LABEL_KEY = resilient-orders.io/gateway-routes
GATEWAY_ROUTE_LABEL_VALUE = allowed
TF_ROOT_DIR = infra/terraform
TF_CODESPACES_DIR = infra/terraform/codespaces
TF_PLATFORM_DIR = infra/terraform/platform
TF_ORACLE_DIR = infra/terraform/oracle
GITOPS_REPO_URL ?= $(shell git config --get remote.origin.url 2>/dev/null)

# -----------------------------
# Docker Compose: common stack
# -----------------------------

# Build every image declared in the base Compose file.
build:
	docker compose build

# Start only the Docker Compose infrastructure services useful for local
# experiments with Vault and RabbitMQ without running the full application stack.
infra-up:
	docker compose up -d vault rabbitmq

# Start the full local development stack.
up:
	docker compose up -d

# Stop containers without deleting them or their volumes.
stop:
	docker compose stop

# Stop and remove containers/networks created by Compose.
# Named volumes are kept unless `docker compose down -v` is used manually.
down:
	docker compose down

# Show current container status for the base Compose project.
ps:
	docker compose ps

# Validate the fully rendered Compose configuration.
config:
	docker compose config --quiet

# -----------------------------
# Terraform: GitOps bootstrap
# -----------------------------

# Format Terraform files in place across all layers.
terraform-fmt:
	terraform -chdir=$(TF_ROOT_DIR) fmt -recursive

# Initialize the local k3d cluster layer.
terraform-codespaces-init:
	terraform -chdir=$(TF_CODESPACES_DIR) init

# Plan local k3d cluster creation.
terraform-codespaces-plan:
	terraform -chdir=$(TF_CODESPACES_DIR) plan

# Create or reuse the local k3d cluster.
terraform-codespaces-apply:
	terraform -chdir=$(TF_CODESPACES_DIR) apply

# Delete the local k3d cluster through the terraform_data destroy provisioner.
terraform-codespaces-destroy:
	terraform -chdir=$(TF_CODESPACES_DIR) destroy

# Initialize the platform layer that targets an existing Kubernetes context.
terraform-platform-init:
	terraform -chdir=$(TF_PLATFORM_DIR) init

# Validate platform Terraform syntax and provider configuration.
terraform-platform-validate:
	terraform -chdir=$(TF_PLATFORM_DIR) validate

# Show platform bootstrap changes Terraform would make.
terraform-platform-plan:
	terraform -chdir=$(TF_PLATFORM_DIR) plan \
		-var="repository_url=$(GITOPS_REPO_URL)"

# Apply the platform GitOps bootstrap:
# - install platform controllers/operators;
# - install Argo CD;
# - create the first Argo CD Application for the PostgreSQL-only platform slice.
terraform-platform-apply:
	terraform -chdir=$(TF_PLATFORM_DIR) apply \
		-var="repository_url=$(GITOPS_REPO_URL)"

# Destroy platform resources before deleting the Kubernetes cluster.
terraform-platform-destroy:
	terraform -chdir=$(TF_PLATFORM_DIR) destroy \
		-var="repository_url=$(GITOPS_REPO_URL)"

# Convenience target: initialize all local GitOps Terraform layers.
terraform-init: terraform-codespaces-init terraform-platform-init

# Convenience target: validate the platform layer.
terraform-validate: terraform-platform-validate

# Convenience target: plan the local cluster layer.
#
# Platform planning requires a reachable Kubernetes context, so use
# `make terraform-platform-plan` after the k3d cluster exists.
terraform-plan: terraform-codespaces-plan

# Convenience target: create local cluster first, then install platform.
terraform-apply: terraform-codespaces-apply terraform-platform-apply

# Convenience target: remove platform first, then delete local cluster.
terraform-destroy: terraform-platform-destroy terraform-codespaces-destroy

# -----------------------------
# GitHub Actions: local runner
# -----------------------------

# Start an ephemeral self-hosted runner inside Codespaces.
#
# The runner only waits for a GitHub Actions job. Terraform is executed later by
# the workflow in .github/workflows/gitops-bootstrap-codespaces.yml.
github-runner-start:
	bash infra/github-actions/start-codespaces-runner.sh

# Unregister a persistent local runner. Ephemeral runners usually remove
# themselves after finishing one job.
github-runner-cleanup:
	bash infra/github-actions/cleanup-codespaces-runner.sh

# -----------------------------
# Helm: production-shaped stack
# -----------------------------

# Install External Secrets Operator through its official Helm chart.
#
# Helm renders Kubernetes YAML and exits; it is not a background daemon. The
# long-running part is the External Secrets Operator controller Pod installed by
# this command. installCRDs=true installs the ExternalSecret/SecretStore CRDs.
helm-external-secrets:
	helm repo add external-secrets https://charts.external-secrets.io
	helm upgrade --install external-secrets external-secrets/external-secrets \
		--namespace external-secrets \
		--create-namespace \
		--wait \
		--timeout 2m \
		--history-max 3 \
		--set installCRDs=true \
		--set resources.requests.cpu=10m \
		--set resources.requests.memory=64Mi \
		--set resources.limits.cpu=100m \
		--set resources.limits.memory=128Mi

# Install Strimzi Kafka Operator. Kafka itself is declared in this project's
# Helm chart through Kafka, KafkaNodePool and KafkaTopic custom resources.
helm-strimzi-operator:
	helm upgrade --install strimzi-kafka-operator oci://quay.io/strimzi-helm/strimzi-kafka-operator \
		--version 1.1.0 \
		--namespace $(STRIMZI_NAMESPACE) \
		--create-namespace \
		--wait \
		--timeout 3m \
		--history-max 3 \
		--set watchAnyNamespace=true \
		--set replicas=1 \
		--set resources.requests.cpu=25m \
		--set resources.requests.memory=128Mi \
		--set resources.limits.cpu=300m \
		--set resources.limits.memory=384Mi \
		--set extraEnvs[0].name=STRIMZI_ENTITY_OPERATOR_WATCHED_NAMESPACE_ENABLED \
		--set extraEnvs[0].value=true

# Install Gateway API CRDs and NGINX Gateway Fabric. Gateway API separates
# admin-owned Gateway infrastructure from developer-owned HTTPRoute rules.
helm-gateway-api-crds:
	kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.6.7" | kubectl apply -f -

helm-nginx-gateway: helm-gateway-api-crds
	helm upgrade --install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
		--version 2.6.7 \
		--namespace $(NGINX_GATEWAY_NAMESPACE) \
		--create-namespace \
		--wait \
		--timeout 3m \
		--history-max 3 \
		--set nginx.service.type=LoadBalancer \
		--set nginxGateway.replicaCount=1 \
		--set nginxGateway.resources.requests.cpu=25m \
		--set nginxGateway.resources.requests.memory=96Mi \
		--set nginxGateway.resources.limits.cpu=300m \
		--set nginxGateway.resources.limits.memory=256Mi

# Platform operators installed by an admin/platform role before application
# releases are deployed.
helm-operators: helm-external-secrets helm-strimzi-operator helm-nginx-gateway

# Create only the local Vault bootstrap token Secrets.
#
# `bash -ec` runs one Bash script and stops on the first failing command.
# `set -a; . ./.env; set +a` temporarily exports every variable from .env so
# kubectl can read local secret values without committing them to Git.
helm-vault-token-source:
	bash -ec 'set -a; . ./.env; set +a; \
		kubectl create namespace $(HELM_PLATFORM_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -; \
		kubectl create namespace $(HELM_APP_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -; \
		kubectl label namespace $(HELM_PLATFORM_NAMESPACE) $(GATEWAY_ROUTE_LABEL_KEY)=$(GATEWAY_ROUTE_LABEL_VALUE) --overwrite; \
		kubectl label namespace $(HELM_APP_NAMESPACE) $(GATEWAY_ROUTE_LABEL_KEY)=$(GATEWAY_ROUTE_LABEL_VALUE) --overwrite; \
		kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -; \
		kubectl create secret generic $(HELM_VAULT_DEV_TOKEN_SECRET_NAME) --namespace $(HELM_PLATFORM_NAMESPACE) --from-literal=token="$$VAULT_DEV_ROOT_TOKEN_ID" --dry-run=client -o yaml | kubectl apply -f -; \
		kubectl create secret generic $(HELM_VAULT_TOKEN_SECRET_NAME) --namespace external-secrets --from-literal=token="$$VAULT_DEV_ROOT_TOKEN_ID" --dry-run=client -o yaml | kubectl apply -f -'

# Seed local HashiCorp Vault from .env.
#
# In cloud mode this target should disappear: OCI Vault / a cloud secret manager
# owns secret values, while ExternalSecret manifests keep the same shape.
helm-vault-seed:
	kubectl wait deployment/vault --namespace $(HELM_PLATFORM_NAMESPACE) --for=condition=Available --timeout=3m
	bash -ec 'set -a; . ./.env; set +a; \
		kubectl exec --namespace $(HELM_PLATFORM_NAMESPACE) deploy/vault -- env VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN="$$VAULT_DEV_ROOT_TOKEN_ID" vault kv put secret/resilient-orders \
			POSTGRES_PASSWORD="$$POSTGRES_PASSWORD" \
			POSTGRES_EXPORTER_PASSWORD="$$POSTGRES_EXPORTER_PASSWORD" \
			ORDER_SERVICE_DB_OWNER_PASSWORD="$$ORDER_SERVICE_DB_OWNER_PASSWORD" \
			ORDER_SERVICE_DB_PASSWORD="$$ORDER_SERVICE_DB_PASSWORD" \
			NOTIFICATION_SERVICE_DB_OWNER_PASSWORD="$$NOTIFICATION_SERVICE_DB_OWNER_PASSWORD" \
			NOTIFICATION_SERVICE_DB_PASSWORD="$$NOTIFICATION_SERVICE_DB_PASSWORD" \
			JWT_SECRET="$$JWT_SECRET" \
			RABBITMQ_ADMIN_USERNAME="$$RABBITMQ_ADMIN_USERNAME" \
			RABBITMQ_ADMIN_PASSWORD="$$RABBITMQ_ADMIN_PASSWORD" \
			ORDER_SERVICE_RABBITMQ_USERNAME="$$ORDER_SERVICE_RABBITMQ_USERNAME" \
			ORDER_SERVICE_RABBITMQ_PASSWORD="$$ORDER_SERVICE_RABBITMQ_PASSWORD" \
			NOTIFICATION_SERVICE_RABBITMQ_USERNAME="$$NOTIFICATION_SERVICE_RABBITMQ_USERNAME" \
			NOTIFICATION_SERVICE_RABBITMQ_PASSWORD="$$NOTIFICATION_SERVICE_RABBITMQ_PASSWORD" \
			GRAFANA_ADMIN_USER="$$GRAFANA_ADMIN_USER" \
			GRAFANA_ADMIN_PASSWORD="$$GRAFANA_ADMIN_PASSWORD" \
			ORDER_SERVICE_ADMIN_USERNAME="$$ORDER_SERVICE_ADMIN_USERNAME" \
			ORDER_SERVICE_ADMIN_PASSWORD="$$ORDER_SERVICE_ADMIN_PASSWORD" \
			ORDER_SERVICE_USER_USERNAME="$$ORDER_SERVICE_USER_USERNAME" \
			ORDER_SERVICE_USER_PASSWORD="$$ORDER_SERVICE_USER_PASSWORD"'

# Run platform-owned database provisioning once secrets are available in Vault.
helm-db-provision:
	helm upgrade --install $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--reuse-values \
		--wait \
		--timeout 5m \
		--history-max 3 \
		--set database.provisioner.enabled=true
	helm upgrade --install $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--reuse-values \
		--history-max 3 \
		--set database.provisioner.enabled=false

# Import locally built application images into the k3d cluster runtime.
helm-images-import:
	k3d image import resilient-orders/order-service:local --cluster $(K3D_CLUSTER)
	k3d image import resilient-orders/payment-service:local --cluster $(K3D_CLUSTER)
	k3d image import resilient-orders/notification-service:local --cluster $(K3D_CLUSTER)

# Validate both physically separated charts.
helm-lint:
	helm lint $(HELM_ADMIN_CHART)
	helm lint $(HELM_APP_CHART)

# Render the dev chart locally without touching a cluster.
helm-template-dev:
	helm template $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE)
	helm template $(HELM_APP_RELEASE) $(HELM_APP_CHART) \
		--namespace $(HELM_APP_NAMESPACE)

# Render the first GitOps slice: Vault, ExternalSecret and PostgreSQL only.
helm-template-postgres-only:
	helm template $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--values infra/helm/admin/values-postgres-only.yaml

# Render the monitoring profile locally without touching a cluster.
helm-template-monitoring:
	helm template $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--values infra/helm/values-observability-monitoring.yaml

# Render monitoring plus local LoadBalancer exposure without touching a cluster.
helm-template-local-expose:
	helm template $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--values infra/helm/values-observability-monitoring.yaml \
		--values infra/helm/values-local-expose.yaml
	helm template $(HELM_APP_RELEASE) $(HELM_APP_CHART) \
		--namespace $(HELM_APP_NAMESPACE) \
		--values infra/helm/values-observability-monitoring.yaml \
		--values infra/helm/values-local-expose.yaml

# Render monitoring plus Gateway API exposure without touching a cluster.
helm-template-local-gateway:
	helm template $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--values infra/helm/values-observability-monitoring.yaml \
		--values infra/helm/values-local-gateway.yaml
	helm template $(HELM_APP_RELEASE) $(HELM_APP_CHART) \
		--namespace $(HELM_APP_NAMESPACE) \
		--values infra/helm/values-observability-monitoring.yaml \
		--values infra/helm/values-local-gateway.yaml

# Render the Codespaces profile without touching a cluster.
helm-template-codespaces:
	helm template $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--values infra/helm/values-observability-monitoring.yaml \
		--values infra/helm/values-local-gateway.yaml \
		--values infra/helm/values-codespaces.yaml

# Apply the base Helm dev profile manually. GitOps should normally use
# Terraform + Argo CD instead of this target.
helm-dev: helm-vault-token-source
	helm upgrade --install $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--create-namespace \
		--history-max 3
	$(MAKE) helm-vault-seed
	$(MAKE) helm-db-provision
	helm upgrade --install $(HELM_APP_RELEASE) $(HELM_APP_CHART) \
		--namespace $(HELM_APP_NAMESPACE) \
		--create-namespace \
		--history-max 3

# Apply dev plus lightweight monitoring: postgres-exporter, Prometheus, Grafana.
helm-monitoring: helm-vault-token-source
	helm upgrade --install $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--create-namespace \
		--history-max 3 \
		--values infra/helm/values-observability-monitoring.yaml
	$(MAKE) helm-vault-seed

# Apply monitoring plus local LoadBalancer exposure.
helm-local-expose: helm-vault-token-source
	helm upgrade --install $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--create-namespace \
		--history-max 3 \
		--values infra/helm/values-observability-monitoring.yaml \
		--values infra/helm/values-local-expose.yaml
	$(MAKE) helm-vault-seed
	$(MAKE) helm-db-provision
	helm upgrade --install $(HELM_APP_RELEASE) $(HELM_APP_CHART) \
		--namespace $(HELM_APP_NAMESPACE) \
		--create-namespace \
		--history-max 3 \
		--values infra/helm/values-observability-monitoring.yaml \
		--values infra/helm/values-local-expose.yaml

# Apply monitoring plus Gateway API exposure.
helm-local-gateway: helm-vault-token-source
	helm upgrade --install $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--create-namespace \
		--history-max 3 \
		--values infra/helm/values-observability-monitoring.yaml \
		--values infra/helm/values-local-gateway.yaml
	$(MAKE) helm-vault-seed
	$(MAKE) helm-db-provision
	helm upgrade --install $(HELM_APP_RELEASE) $(HELM_APP_CHART) \
		--namespace $(HELM_APP_NAMESPACE) \
		--create-namespace \
		--history-max 3 \
		--values infra/helm/values-observability-monitoring.yaml \
		--values infra/helm/values-local-gateway.yaml

# Apply the constrained Codespaces profile manually.
helm-codespaces: helm-vault-token-source
	helm upgrade --install $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--create-namespace \
		--history-max 3 \
		--values infra/helm/values-observability-monitoring.yaml \
		--values infra/helm/values-local-gateway.yaml \
		--values infra/helm/values-codespaces.yaml

# Deploy only persistent platform dependencies and Strimzi-managed Kafka.
helm-platform: helm-vault-token-source
	helm upgrade --install $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--create-namespace \
		--wait \
		--timeout 8m \
		--history-max 3 \
		--values infra/helm/values-local-gateway.yaml \
		--values infra/helm/values-codespaces.yaml \
		--values infra/helm/values-stage-platform.yaml
	$(MAKE) helm-vault-seed
	$(MAKE) helm-db-provision
	kubectl wait kafka/$(KAFKA_CLUSTER) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--for=condition=Ready \
		--timeout=10m

# Enable Schema Registry after the Strimzi Kafka cluster has been reconciled.
helm-schema-registry:
	helm upgrade --install $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--reuse-values \
		--wait \
		--timeout 8m \
		--history-max 3 \
		--set components.schemaRegistry.enabled=true

# Enable application Deployments after infrastructure is ready.
helm-apps:
	helm upgrade --install $(HELM_APP_RELEASE) $(HELM_APP_CHART) \
		--namespace $(HELM_APP_NAMESPACE) \
		--create-namespace \
		--wait \
		--timeout 10m \
		--history-max 3 \
		--values infra/helm/values-local-gateway.yaml \
		--values infra/helm/values-codespaces.yaml \
		--set components.paymentService.enabled=true \
		--set components.orderService.enabled=true \
		--set components.notificationService.enabled=true

# Enable observability after core workloads are running.
helm-observability:
	helm upgrade --install $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--reuse-values \
		--wait \
		--timeout 6m \
		--history-max 3 \
		--set observability.tracing.enabled=true \
		--set observability.monitoring.enabled=true
	helm upgrade --install $(HELM_APP_RELEASE) $(HELM_APP_CHART) \
		--namespace $(HELM_APP_NAMESPACE) \
		--reuse-values \
		--wait \
		--timeout 6m \
		--history-max 3 \
		--set observability.monitoring.enabled=true \
		--set routes.enabled=true

# Production-shaped local deployment flow:
# operators -> infrastructure -> schema registry -> apps -> observability.
helm-prod-like: helm-operators helm-platform helm-schema-registry helm-apps helm-observability

# Apply dev plus explicit tracing profile.
helm-tracing: helm-vault-token-source
	helm upgrade --install $(HELM_ADMIN_RELEASE) $(HELM_ADMIN_CHART) \
		--namespace $(HELM_PLATFORM_NAMESPACE) \
		--create-namespace \
		--history-max 3 \
		--values infra/helm/values-observability-tracing.yaml

# Apply the load-test profile.
helm-load: helm-vault-token-source
	helm upgrade --install $(HELM_APP_RELEASE) $(HELM_APP_CHART) \
		--namespace $(HELM_APP_NAMESPACE) \
		--create-namespace \
		--history-max 3 \
		--values infra/helm/values-load-test.yaml

# Remove the Helm releases. Namespace cleanup is intentionally separate so PVCs
# are not deleted accidentally by a short command.
helm-delete:
	helm uninstall $(HELM_APP_RELEASE) --namespace $(HELM_APP_NAMESPACE) --ignore-not-found
	helm uninstall $(HELM_ADMIN_RELEASE) --namespace $(HELM_PLATFORM_NAMESPACE) --ignore-not-found

# Remove the application release, namespaces and platform operators installed
# through manual Helm targets.
helm-delete-all:
	helm uninstall $(HELM_APP_RELEASE) --namespace $(HELM_APP_NAMESPACE) --ignore-not-found
	helm uninstall $(HELM_ADMIN_RELEASE) --namespace $(HELM_PLATFORM_NAMESPACE) --ignore-not-found
	kubectl delete namespace $(HELM_APP_NAMESPACE) --ignore-not-found
	kubectl delete namespace $(HELM_PLATFORM_NAMESPACE) --ignore-not-found
	helm uninstall external-secrets --namespace external-secrets --ignore-not-found
	kubectl delete namespace external-secrets --ignore-not-found
	helm uninstall strimzi-kafka-operator --namespace $(STRIMZI_NAMESPACE) --ignore-not-found
	kubectl delete namespace $(STRIMZI_NAMESPACE) --ignore-not-found
	helm uninstall ngf --namespace $(NGINX_GATEWAY_NAMESPACE) --ignore-not-found
	kubectl delete namespace $(NGINX_GATEWAY_NAMESPACE) --ignore-not-found

# -----------------------------
# Docker Compose: load testing
# -----------------------------

# Start the reduced load-test stack.
# The override file enables docker,load-test profiles for order-service.
load-up:
	$(COMPOSE_LOAD_TEST) up -d grafana order-service

# Build only the service used by the HTTP/Gatling load-test scenario.
load-build:
	$(COMPOSE_LOAD_TEST) build order-service

# Stop containers from the load-test Compose view.
load-stop:
	$(COMPOSE_LOAD_TEST) stop

# Remove containers/networks from the load-test Compose view.
load-down:
	$(COMPOSE_LOAD_TEST) down

# Validate the rendered load-test Compose configuration.
load-config:
	$(COMPOSE_LOAD_TEST) config --quiet
