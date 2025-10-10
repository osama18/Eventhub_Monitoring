# EventHub Custom Metrics Emitter - Java
# Minimal Makefile for Azure deployment

.PHONY: help compile package docker-build az-login acr-push az-deploy all redeploy clean

# Default target
help:
	@echo "Available targets: compile, package, docker-build, az-login, acr-push, az-deploy, all, redeploy, clean, help"
	@echo ""
	@echo "🚀 Quick redeploy: make redeploy (builds & pushes new image, updates container app)"

# Compile the Java code
compile:
	@echo "Compiling Java code..."
	mvn clean compile

# Build the JAR file
package: compile
	@echo "Building JAR file..."
	mvn clean package -DskipTests

# Build Docker image
docker-build: package
	@echo "Building Docker image..."
	docker build -f src/Dockerfile -t eventhub-custom-metrics-emitter-java:latest .

# Azure Login
az-login:
	@echo "Logging into Azure..."
	az login

# Push to Azure Container Registry
acr-push: docker-build
	@echo "Pushing to Azure Container Registry..."
	@if [ -z "$(ACR_NAME)" ]; then \
		read -p "Enter your ACR name: " ACR_NAME; \
		read -p "Enter Resource Group [eh-lag-metric-rg]: " RESOURCE_GROUP; \
		RESOURCE_GROUP=$${RESOURCE_GROUP:-eh-lag-metric-rg}; \
		read -p "Enter Location [uksouth]: " LOCATION; \
		LOCATION=$${LOCATION:-uksouth}; \
	else \
		ACR_NAME=$(ACR_NAME); \
		RESOURCE_GROUP=$(RESOURCE_GROUP); \
		LOCATION=$(LOCATION); \
	fi; \
	if ! az acr show --name $$ACR_NAME --resource-group $$RESOURCE_GROUP >/dev/null 2>&1; then \
		az acr create --name $$ACR_NAME --resource-group $$RESOURCE_GROUP --location $$LOCATION --sku Basic; \
	fi; \
	az acr login --name $$ACR_NAME; \
	docker tag eventhub-custom-metrics-emitter-java:latest $$ACR_NAME.azurecr.io/eventhub-custom-metrics-emitter-java:latest; \
	docker push $$ACR_NAME.azurecr.io/eventhub-custom-metrics-emitter-java:latest

# Azure deployment command (renamed from azdeploy)
az-deploy:
	@echo "Deploying to Azure..."
	@if [ -z "$(ACR_NAME)" ]; then \
		read -p "Resource Group Name: " RESOURCE_GROUP; \
		read -p "Enter your ACR name: " ACR_NAME; \
	else \
		ACR_NAME=$(ACR_NAME); \
		RESOURCE_GROUP=$(RESOURCE_GROUP); \
	fi; \
	az deployment group create \
		--resource-group "$$RESOURCE_GROUP" \
		--template-file deploy/bicep/main.bicep \
		--parameters @deploy/bicep/param.json \
		--parameters AcrName=$$ACR_NAME

# Complete pipeline: ACR push + Azure deploy
all:
	@echo "Running complete deployment pipeline..."
	@read -p "Enter your ACR name: " ACR_NAME; \
	read -p "Enter Resource Group [eh-lag-metric-rg]: " RESOURCE_GROUP; \
	RESOURCE_GROUP=$${RESOURCE_GROUP:-eh-lag-metric-rg}; \
	read -p "Enter Location [uksouth]: " LOCATION; \
	LOCATION=$${LOCATION:-uksouth}; \
	$(MAKE) acr-push ACR_NAME=$$ACR_NAME RESOURCE_GROUP=$$RESOURCE_GROUP LOCATION=$$LOCATION; \
	$(MAKE) az-deploy ACR_NAME=$$ACR_NAME RESOURCE_GROUP=$$RESOURCE_GROUP

# Redeploy container app with latest image (fast update)
redeploy: docker-build
	@echo "🚀 Redeploying container app with latest image..."
	@if [ -z "$(ACR_NAME)" ]; then \
		read -p "Enter your ACR name: " ACR_NAME; \
		read -p "Enter Resource Group [eh-lag-metric-rg]: " RESOURCE_GROUP; \
		RESOURCE_GROUP=$${RESOURCE_GROUP:-eh-lag-metric-rg}; \
	else \
		ACR_NAME=$(ACR_NAME); \
		RESOURCE_GROUP=$(RESOURCE_GROUP); \
	fi; \
	echo "📦 Pushing new image to ACR..."; \
	az acr login --name $$ACR_NAME; \
	docker tag eventhub-custom-metrics-emitter-java:latest $$ACR_NAME.azurecr.io/eventhub-custom-metrics-emitter-java:latest; \
	docker push $$ACR_NAME.azurecr.io/eventhub-custom-metrics-emitter-java:latest; \
	echo "🔄 Restarting container app to pull latest image..."; \
	REVISION=$$(az containerapp revision list --name eh-lag-emitter-java --resource-group $$RESOURCE_GROUP --query "[0].name" -o tsv); \
	az containerapp revision restart --name eh-lag-emitter-java --resource-group $$RESOURCE_GROUP --revision $$REVISION; \
	echo "✅ Container app redeployed successfully!"

# Clean up Azure resources created by 'make all'
clean:
	@echo "Cleaning up Azure resources created by 'make all'..."
	@read -p "Enter your ACR name: " ACR_NAME; \
	read -p "Enter Resource Group [eh-lag-metric-rg]: " RESOURCE_GROUP; \
	RESOURCE_GROUP=$${RESOURCE_GROUP:-eh-lag-metric-rg}; \
	read -p "Are you sure you want to delete these Azure resources? (yes/NO): " CONFIRM; \
	if [ "$$CONFIRM" = "yes" ]; then \
		echo "🗑️  Deleting Azure Container App..."; \
		az containerapp delete --name eh-lag-emitter-java --resource-group "$$RESOURCE_GROUP" --yes 2>/dev/null || echo "Container app not found or already deleted"; \
		echo "🗑️  Deleting Container App Environment..."; \
		az containerapp env delete --name my-container-app-env-java-v4 --resource-group "$$RESOURCE_GROUP" --yes 2>/dev/null || echo "Container app environment not found or already deleted"; \
		echo "🗑️  Deleting Log Analytics Workspace..."; \
		az monitor log-analytics workspace delete --workspace-name emitter-log-analytics-java --resource-group "$$RESOURCE_GROUP" --yes 2>/dev/null || echo "Log analytics workspace not found or already deleted"; \
		echo "🗑️  Deleting Managed Identity..."; \
		az identity delete --name eventhub-metrics-identity-java-v4 --resource-group "$$RESOURCE_GROUP" 2>/dev/null || echo "Managed identity not found or already deleted"; \
		echo "🗑️  Deleting Azure Container Registry..."; \
		az acr delete --name "$$ACR_NAME" --resource-group "$$RESOURCE_GROUP" --yes 2>/dev/null || echo "ACR not found or already deleted"; \
		echo "✅ Azure resource cleanup completed! Local artifacts preserved for development."; \
	else \
		echo "❌ Cleanup cancelled."; \
	fi