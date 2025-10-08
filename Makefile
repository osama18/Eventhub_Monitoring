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
	@echo "Azure Deployment:"
	@echo "  github-push  - Build and push Docker image to GitHub Container Registry"
	@echo "  az-deploy    - Login to Azure and deploy to Container Apps (prompts for subscription/RG)"
	@echo "  deploy-all   - Full deployment pipeline (github-push + az-deploy)"
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
	mvn clean package

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
ci: clean compile test package
	@echo "CI pipeline completed successfully!"

# Azure deployment command (login + deploy)
az-deploy:
	@echo "Azure Login and Deployment..."
	@echo "Logging into Azure..."
	az login
	@echo "You will be prompted for Azure configuration..."
	@read -p "Subscription ID: " SUBSCRIPTION_ID; \
	read -p "Resource Group Name: " RESOURCE_GROUP; \
	echo "Setting subscription to $$SUBSCRIPTION_ID..."; \
	az account set --subscription "$$SUBSCRIPTION_ID"; \
	echo "Deploying to resource group $$RESOURCE_GROUP..."; \
	az deployment group create \
		--resource-group "$$RESOURCE_GROUP" \
		--template-file deploy/bicep/main.bicep \
		--parameters @deploy/bicep/param.json

# Push to GitHub Container Registry
github-push: docker-build
	@echo "Pushing to GitHub Container Registry..."
	@echo "Make sure you have GITHUB_TOKEN set and are logged in!"
	docker tag eventhub-custom-metrics-emitter-java:latest ghcr.io/azure-samples-java/eventhub-custom-metrics-emitter-java:latest
	docker push ghcr.io/azure-samples-java/eventhub-custom-metrics-emitter-java:latest
	@echo "Image pushed to ghcr.io/azure-samples-java/eventhub-custom-metrics-emitter-java:latest"

# Build, push, and deploy (full pipeline)
deploy-all: github-push az-deploy
	@echo "Full deployment pipeline completed successfully!"