#!/bin/bash

# Script to create Azure Storage Account for Terraform remote state
# This script should be run once to set up the backend infrastructure

set -e

# Variables
SUBSCRIPTION_ID="fcde6cf3-f69d-4b81-9ae3-7c1187597de0"
RESOURCE_GROUP_NAME="cdpp-infra"
STORAGE_ACCOUNT_NAME="cdppterraformstate"
CONTAINER_NAME="tfstate"
LOCATION="North Europe"

echo "Setting up Azure Storage Account for Terraform remote state..."

# Login to Azure (if not already logged in)
az login --output table

# Set the subscription
az account set --subscription $SUBSCRIPTION_ID

# Check if storage account already exists
if az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP_NAME &> /dev/null; then
    echo "Storage account $STORAGE_ACCOUNT_NAME already exists."
else
    echo "Creating storage account $STORAGE_ACCOUNT_NAME..."
    az storage account create \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $STORAGE_ACCOUNT_NAME \
        --sku Standard_LRS \
        --encryption-services blob \
        --https-only true \
        --kind StorageV2 \
        --location "$LOCATION" \
        --access-tier Hot
fi

# Get storage account key
ACCOUNT_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query '[0].value' -o tsv)

# Check if container already exists
if az storage container show --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --account-key $ACCOUNT_KEY &> /dev/null; then
    echo "Container $CONTAINER_NAME already exists."
else
    echo "Creating container $CONTAINER_NAME..."
    az storage container create \
        --name $CONTAINER_NAME \
        --account-name $STORAGE_ACCOUNT_NAME \
        --account-key $ACCOUNT_KEY
fi

echo "Azure Storage setup complete!"
echo ""
echo "Backend configuration details:"
echo "  Resource Group: $RESOURCE_GROUP_NAME"
echo "  Storage Account: $STORAGE_ACCOUNT_NAME"
echo "  Container: $CONTAINER_NAME"
echo ""
echo "You can now update your Terraform configurations to use this remote backend."
