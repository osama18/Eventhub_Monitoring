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

# Create terraform.tfvars
cat > terraform.tfvars <<TFVARS
subscription_id         = "$SUBSCRIPTION_ID"
resource_group_name     = "$RESOURCE_GROUP_NAME"
eventhub_namespace_name = "$EVENTHUB_NAMESPACE_NAME"
TFVARS

# Initialize Terraform
terraform init

# Plan the changes
terraform plan

# Apply the changes
terraform apply -auto-approve

echo "Deployment complete!"
