#!/bin/bash

# Script to create Azure Storage Account for Terraform remote state
# This script should be run once to set up the backend infrastructure

set -e

echo "Azure Storage Backend Setup for Terraform"
echo "=========================================="
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

# Prompt for backend storage variables
read -p "Enter Resource Group Name for backend storage: " RESOURCE_GROUP_NAME
read -p "Enter Storage Account Name (lowercase, no special chars): " STORAGE_ACCOUNT_NAME
read -p "Enter Container Name (default: tfstate): " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-tfstate}
read -p "Enter Location (default: uksouth): " LOCATION
LOCATION=${LOCATION:-uksouth}

echo ""
echo "Configuration:"
echo "  Resource Group: $RESOURCE_GROUP_NAME"
echo "  Storage Account: $STORAGE_ACCOUNT_NAME"
echo "  Container: $CONTAINER_NAME"
echo "  Location: $LOCATION"
echo ""

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

echo ""
echo "Azure Storage setup complete!"
echo ""
echo "Backend configuration details:"
echo "  Resource Group: $RESOURCE_GROUP_NAME"
echo "  Storage Account: $STORAGE_ACCOUNT_NAME"
echo "  Container: $CONTAINER_NAME"
echo ""
