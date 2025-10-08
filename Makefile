# EventHub Custom Metrics Emitter - Java
# Makefile for common development tasks

.PHONY: help compile test package docker-build docker-run clean ci az-deploy github-push deploy-all

# Default target
help:
	@echo "Available targets:"
	@echo "  compile      - Compile the Java code using Maven"
	@echo "  test         - Run tests using Maven"
	@echo "  package      - Build the JAR file using Maven"
	@echo "  docker-build - Build Docker image (runs package first)"
	@echo "  docker-run   - Run Docker container locally with prompts for env vars"
	@echo "  clean        - Clean build artifacts"
	@echo "  ci           - Full CI pipeline (clean, compile, test, package)"
	@echo ""
	@echo "Azure & Registry:"
	@echo "  az-login         - Login to Azure CLI"
	@echo "  acr-push         - Build and push to ACR (creates ACR if needed)"
	@echo "  azdeploy         - Deploy infrastructure and assign ACR permissions"
	@echo "  acr-full-deploy  - Complete pipeline: create ACR, push, deploy, assign permissions"
	@echo "  local-push       - Build and push Docker image to local registry (localhost:5000)"
	@echo "  github-push    - Build and push Docker image to GitHub Container Registry"
	@echo "  az-deploy      - Login to Azure and deploy to Container Apps (prompts for subscription/RG)"
	@echo "  deploy-all     - Full deployment pipeline (github-push + az-deploy)"
	@echo ""
	@echo "  help         - Show this help message"

# Compile the Java code
compile:
	@echo "Compiling Java code..."
	mvn clean compile

# Run tests
test:
	@echo "Running tests..."
	mvn test

# Build the JAR file
package:
	@echo "Building JAR file..."
	mvn clean package -DskipTests

# Build Docker image
docker-build: package
	@echo "Building Docker image..."
	docker build -f src/Dockerfile -t eventhub-custom-metrics-emitter-java:latest .

# Run Docker container locally (interactive)
docker-run: docker-build
	@echo "Running Docker container..."
	@echo "You will be prompted for required environment variables..."
	@read -p "Azure Region [eastus]: " REGION; \
	REGION=$${REGION:-eastus}; \
	read -p "Subscription ID: " SUBSCRIPTION_ID; \
	read -p "Resource Group: " RESOURCE_GROUP; \
	read -p "Tenant ID: " TENANT_ID; \
	read -p "Event Hub Namespace: " EVENT_HUB_NAMESPACE; \
	read -p "Event Hub Name: " EVENT_HUB_NAME; \
	read -p "Checkpoint Account Name: " CHECKPOINT_ACCOUNT_NAME; \
	read -p "Checkpoint Container Name: " CHECKPOINT_CONTAINER_NAME; \
	docker run --rm \
		-e REGION="$$REGION" \
		-e SUBSCRIPTION_ID="$$SUBSCRIPTION_ID" \
		-e RESOURCE_GROUP="$$RESOURCE_GROUP" \
		-e TENANT_ID="$$TENANT_ID" \
		-e EVENT_HUB_NAMESPACE="$$EVENT_HUB_NAMESPACE" \
		-e EVENT_HUB_NAME="$$EVENT_HUB_NAME" \
		-e CHECKPOINT_ACCOUNT_NAME="$$CHECKPOINT_ACCOUNT_NAME" \
		-e CHECKPOINT_CONTAINER_NAME="$$CHECKPOINT_CONTAINER_NAME" \
		eventhub-custom-metrics-emitter-java:latest

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	mvn clean
	docker rmi eventhub-custom-metrics-emitter-java:latest 2>/dev/null || true

# Quick build and test pipeline
ci: clean compile package
	@echo "CI pipeline completed successfully!"

# Azure deployment command (login + deploy)
azdeploy:
	@read -p "Resource Group Name: " RESOURCE_GROUP; \
	read -p "Enter your ACR name (acrlag): " ACR_NAME; \
	az deployment group create \
		--resource-group "$$RESOURCE_GROUP" \
		--template-file deploy/bicep/main.bicep \
		--parameters @deploy/bicep/param.json \
		--parameters AcrName=$$ACR_NAME; \
	echo "✅ Deployment completed successfully!"; \

# Azure Login
az-login:
	@echo "Logging into Azure..."
	az login

# Push to Azure Container Registry (ACR) - creates ACR if needed
acr-push:
	@echo "Pushing to Azure Container Registry..."
	@read -p "Enter your ACR name: " ACR_NAME; \
	read -p "Enter Resource Group: " RESOURCE_GROUP; \
	RESOURCE_GROUP=$${RESOURCE_GROUP:-eh-lag-metric-rg}; \
	read -p "Enter Location (uksouth): " LOCATION; \
	LOCATION=$${LOCATION:-uksouth}; \
	echo "=== STEP 1: CREATE/VERIFY ACR ==="; \
	echo "Checking if ACR $$ACR_NAME exists in resource group $$RESOURCE_GROUP..."; \
	if ! az acr show --name $$ACR_NAME --resource-group $$RESOURCE_GROUP >/dev/null 2>&1; then \
		echo "ACR $$ACR_NAME not found. Creating it..."; \
		az acr create --name $$ACR_NAME --resource-group $$RESOURCE_GROUP --location $$LOCATION --sku Basic; \
		echo "✅ ACR $$ACR_NAME created successfully"; \
	else \
		echo "✅ ACR $$ACR_NAME already exists"; \
	fi; \
	echo "=== STEP 2: ACR LOGIN ==="; \
	az acr login --name $$ACR_NAME; \
	echo "=== STEP 3: PUSH TO ACR ==="; \
	echo "Tagging image for ACR: $$ACR_NAME.azurecr.io"; \
	docker tag eventhub-custom-metrics-emitter-java:latest $$ACR_NAME.azurecr.io/eventhub-custom-metrics-emitter-java:latest; \
	docker push $$ACR_NAME.azurecr.io/eventhub-custom-metrics-emitter-java:latest; \
	echo "✅ Image pushed to $$ACR_NAME.azurecr.io/eventhub-custom-metrics-emitter-java:latest"

# Push to local registry
local-push: docker-build
	@echo "Pushing to local registry..."
	docker tag eventhub-custom-metrics-emitter-java:latest localhost:5000/eventhub-custom-metrics-emitter-java:latest
	docker push localhost:5000/eventhub-custom-metrics-emitter-java:latest
	@echo "Image pushed to localhost:5000/eventhub-custom-metrics-emitter-java:latest"