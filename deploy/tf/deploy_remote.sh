#!/bin/bash

# Script to deploy with Azure remote backend
# Automatically sets up backend storage if needed
# Note: Requires Azure AD authentication (Storage Blob Data Contributor role)

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
echo "Configure diagnostic log destinations:"
echo "======================================"

# Prompt for Log Analytics (default: yes)
read -p "Enable Log Analytics workspace? (Y/n): " LOG_ANALYTICS_CHOICE
LOG_ANALYTICS_CHOICE=${LOG_ANALYTICS_CHOICE:-Y}
if [[ $LOG_ANALYTICS_CHOICE =~ ^[Yy]$ ]]; then
    ENABLE_LOG_ANALYTICS="true"
else
    ENABLE_LOG_ANALYTICS="false"
fi

# Prompt for Storage Account (default: no)
read -p "Enable Storage Account archiving? (y/N): " STORAGE_CHOICE
STORAGE_CHOICE=${STORAGE_CHOICE:-N}
if [[ $STORAGE_CHOICE =~ ^[Yy]$ ]]; then
    ENABLE_STORAGE="true"
    # Optional: prompt for custom storage account name
    read -p "Enter Storage Account Name (leave empty for auto-generated): " STORAGE_NAME
else
    ENABLE_STORAGE="false"
    STORAGE_NAME=""
fi

# Prompt for Event Hub Streaming (default: no)
read -p "Enable Event Hub streaming? (y/N): " EVENTHUB_CHOICE
EVENTHUB_CHOICE=${EVENTHUB_CHOICE:-N}
if [[ $EVENTHUB_CHOICE =~ ^[Yy]$ ]]; then
    ENABLE_EVENTHUB="true"
else
    ENABLE_EVENTHUB="false"
fi

# Validation: At least one destination must be enabled
if [[ "$ENABLE_LOG_ANALYTICS" == "false" && "$ENABLE_STORAGE" == "false" && "$ENABLE_EVENTHUB" == "false" ]]; then
    echo "Error: At least one diagnostic destination must be enabled!"
    exit 1
fi

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

# Assign Storage Blob Data Contributor role to current user
echo "Ensuring proper permissions on storage account..."
CURRENT_USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
STORAGE_ACCOUNT_ID=$(az storage account show --name $BACKEND_STORAGE_ACCOUNT_NAME --resource-group $BACKEND_RESOURCE_GROUP_NAME --query id -o tsv)

# Check if role assignment already exists
EXISTING_ROLE=$(az role assignment list \
    --assignee $CURRENT_USER_OBJECT_ID \
    --scope $STORAGE_ACCOUNT_ID \
    --role "Storage Blob Data Contributor" \
    --query '[0].id' -o tsv)

if [ -z "$EXISTING_ROLE" ]; then
    echo "Assigning 'Storage Blob Data Contributor' role to current user..."
    az role assignment create \
        --role "Storage Blob Data Contributor" \
        --assignee $CURRENT_USER_OBJECT_ID \
        --scope $STORAGE_ACCOUNT_ID
    
    echo "⏳ Waiting 30 seconds for role assignment to propagate..."
    sleep 30
else
    echo "Role assignment already exists."
fi

# Create or use existing container (using Azure AD authentication)
if az storage container show --name $BACKEND_CONTAINER_NAME --account-name $BACKEND_STORAGE_ACCOUNT_NAME --auth-mode login &> /dev/null; then
    echo "Container $BACKEND_CONTAINER_NAME already exists."
else
    echo "Creating container $BACKEND_CONTAINER_NAME..."
    az storage container create \
        --name $BACKEND_CONTAINER_NAME \
        --account-name $BACKEND_STORAGE_ACCOUNT_NAME \
        --auth-mode login
fi

echo "✅ Backend storage ready!"
echo ""

# Create terraform.tfvars with application configuration
cat > terraform.tfvars <<TFVARS
subscription_id            = "$SUBSCRIPTION_ID"
resource_group_name        = "$RESOURCE_GROUP_NAME"
eventhub_namespace_name    = "$EVENTHUB_NAMESPACE_NAME"
enable_log_analytics       = $ENABLE_LOG_ANALYTICS
enable_storage_account     = $ENABLE_STORAGE
enable_eventhub_streaming  = $ENABLE_EVENTHUB
storage_account_name       = "$STORAGE_NAME"
TFVARS

echo "Created terraform.tfvars"
echo ""

# Set environment variable to disable storage account key polling
# This is required when Azure Policy blocks key-based authentication
export ARM_STORAGE_USE_AZUREAD=true

# Initialize with remote backend using -backend-config (using Azure AD authentication)
echo "Initializing Terraform with remote backend..."
terraform init \
  -backend-config="resource_group_name=$BACKEND_RESOURCE_GROUP_NAME" \
  -backend-config="storage_account_name=$BACKEND_STORAGE_ACCOUNT_NAME" \
  -backend-config="container_name=$BACKEND_CONTAINER_NAME" \
  -backend-config="key=eventhub-monitoring/terraform.tfstate" \
  -backend-config="use_azuread_auth=true"

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