#!/bin/bash

set -e

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
echo "Using subscription: $SUBSCRIPTION_ID"
echo ""

# Prompt for resource group name
read -p "Enter Resource Group Name: " RESOURCE_GROUP_NAME

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

# Create terraform.tfvars
cat > terraform.tfvars <<TFVARS
subscription_id            = "$SUBSCRIPTION_ID"
resource_group_name        = "$RESOURCE_GROUP_NAME"
eventhub_namespace_name    = "$EVENTHUB_NAMESPACE_NAME"
enable_log_analytics       = $ENABLE_LOG_ANALYTICS
enable_storage_account     = $ENABLE_STORAGE
enable_eventhub_streaming  = $ENABLE_EVENTHUB
storage_account_name       = "$STORAGE_NAME"
TFVARS

# Initialize Terraform
terraform init

# Plan the changes
terraform plan

# Apply the changes
terraform apply -auto-approve

echo "Deployment complete!"