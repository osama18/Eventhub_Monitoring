#!/bin/bash

# Script to deploy with Azure remote backend
# Automatically sets up backend storage if needed

set -e

echo "Terraform Deployment with Remote State"
echo "======================================="
echo ""

# Check if already logged in to Azure
echo "Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "Not logged in. Logging in to Azure..."
    az login
else
    echo "Already logged in to Azure."
fi

# Get subscription ID from logged in account
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

echo "Using subscription:"
echo "  Name: $SUBSCRIPTION_NAME"
echo "  ID: $SUBSCRIPTION_ID"
echo ""

# Prompt for resource group name
read -p "Enter Resource Group Name (for Event Hub): " RESOURCE_GROUP_NAME

# Prompt for Event Hub namespace name
read -p "Enter Event Hub Namespace Name: " EVENTHUB_NAMESPACE_NAME

echo ""
echo "=== Backend Storage Configuration ==="
echo ""
echo "For remote state, we need Azure Storage backend."
echo ""

# Prompt for backend storage configuration
read -p "Enter Backend Resource Group Name (default: same as Event Hub RG): " BACKEND_RESOURCE_GROUP_NAME
BACKEND_RESOURCE_GROUP_NAME=${BACKEND_RESOURCE_GROUP_NAME:-$RESOURCE_GROUP_NAME}

read -p "Enter Backend Storage Account Name (lowercase, no special chars): " BACKEND_STORAGE_ACCOUNT_NAME
read -p "Enter Backend Container Name (default: tfstate): " BACKEND_CONTAINER_NAME
BACKEND_CONTAINER_NAME=${BACKEND_CONTAINER_NAME:-tfstate}
read -p "Enter Backend Location (default: uksouth): " BACKEND_LOCATION
BACKEND_LOCATION=${BACKEND_LOCATION:-uksouth}

echo ""
echo "Backend Configuration:"
echo "  Resource Group: $BACKEND_RESOURCE_GROUP_NAME"
echo "  Storage Account: $BACKEND_STORAGE_ACCOUNT_NAME"
echo "  Container: $BACKEND_CONTAINER_NAME"
echo "  Location: $BACKEND_LOCATION"
echo ""

# Setup backend storage (idempotent - won't fail if already exists)
echo "Setting up backend storage..."
az account set --subscription $SUBSCRIPTION_ID

# Create or use existing storage account
if az storage account show --name $BACKEND_STORAGE_ACCOUNT_NAME --resource-group $BACKEND_RESOURCE_GROUP_NAME &> /dev/null; then
    echo "Storage account $BACKEND_STORAGE_ACCOUNT_NAME already exists."
else
    echo "Creating storage account $BACKEND_STORAGE_ACCOUNT_NAME..."
    az storage account create \
        --resource-group $BACKEND_RESOURCE_GROUP_NAME \
        --name $BACKEND_STORAGE_ACCOUNT_NAME \
        --sku Standard_LRS \
        --encryption-services blob \
        --https-only true \
        --kind StorageV2 \
        --location "$BACKEND_LOCATION" \
        --access-tier Hot
fi

# Get storage account key
ACCOUNT_KEY=$(az storage account keys list --resource-group $BACKEND_RESOURCE_GROUP_NAME --account-name $BACKEND_STORAGE_ACCOUNT_NAME --query '[0].value' -o tsv)

# Create or use existing container
if az storage container show --name $BACKEND_CONTAINER_NAME --account-name $BACKEND_STORAGE_ACCOUNT_NAME --account-key $ACCOUNT_KEY &> /dev/null; then
    echo "Container $BACKEND_CONTAINER_NAME already exists."
else
    echo "Creating container $BACKEND_CONTAINER_NAME..."
    az storage container create \
        --name $BACKEND_CONTAINER_NAME \
        --account-name $BACKEND_STORAGE_ACCOUNT_NAME \
        --account-key $ACCOUNT_KEY
fi

echo "✅ Backend storage ready!"
echo ""

# Create terraform.tfvars with only application configuration
cat > terraform.tfvars <<TFVARS
subscription_id         = "$SUBSCRIPTION_ID"
resource_group_name     = "$RESOURCE_GROUP_NAME"
eventhub_namespace_name = "$EVENTHUB_NAMESPACE_NAME"
TFVARS

echo "Created terraform.tfvars"
echo ""

# Initialize with remote backend using -backend-config
echo "Initializing Terraform with remote backend..."
terraform init \
  -backend-config="resource_group_name=$BACKEND_RESOURCE_GROUP_NAME" \
  -backend-config="storage_account_name=$BACKEND_STORAGE_ACCOUNT_NAME" \
  -backend-config="container_name=$BACKEND_CONTAINER_NAME" \
  -backend-config="key=eventhub-monitoring/terraform.tfstate"

# Plan the changes
echo ""
echo "Running Terraform plan..."
terraform plan

# Apply the changes
echo ""
echo "Applying Terraform configuration..."
terraform apply -auto-approve

echo ""
echo "Deployment completed successfully!"
echo ""
echo "State is stored in Azure Storage:"
echo "  Resource Group: $BACKEND_RESOURCE_GROUP_NAME"
echo "  Storage Account: $BACKEND_STORAGE_ACCOUNT_NAME"
echo "  Container: $BACKEND_CONTAINER_NAME"
echo "  Key: eventhub-monitoring/terraform.tfstate"

