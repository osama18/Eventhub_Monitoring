#!/bin/bash

# Script to migrate existing Terraform state to Azure remote backend
# Run this script from the directory containing your Terraform configuration

set -e

FABRIC_DIR="/home/eddie/workspace/sitecore.cdppshared.akspoc/setup/terraform/fabric"
AKS_DIR="/home/eddie/workspace/sitecore.cdppshared.akspoc/setup/terraform/aks"

echo "Terraform State Migration Script"
echo "================================"

# Function to migrate state for a specific directory
migrate_state() {
    local DIR=$1
    local NAME=$2
    
    echo ""
    echo "Migrating $NAME Terraform state..."
    echo "Working directory: $DIR"
    
    cd "$DIR"
    
    # Check if terraform.tfstate exists
    if [ -f "terraform.tfstate" ]; then
        echo "Found local state file. Proceeding with migration..."
        
        # Initialize with the new backend
        echo "Initializing Terraform with remote backend..."
        terraform init
        
        echo "$NAME state migration completed successfully!"
    else
        echo "No local state file found in $DIR. Just initializing with remote backend..."
        terraform init
        echo "$NAME backend initialization completed!"
    fi
    
    # Verify the backend configuration
    echo "Verifying backend configuration..."
    terraform providers
}

# Ensure we're logged into Azure
echo "Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "Please log in to Azure first:"
    echo "az login"
    exit 1
fi

echo "Azure login confirmed."

# Migrate fabric state
if [ -d "$FABRIC_DIR" ]; then
    migrate_state "$FABRIC_DIR" "Fabric"
else
    echo "Fabric directory not found: $FABRIC_DIR"
fi

# Migrate AKS state
if [ -d "$AKS_DIR" ]; then
    migrate_state "$AKS_DIR" "AKS"
else
    echo "AKS directory not found: $AKS_DIR"
fi

echo ""
echo "Migration completed!"
echo ""
echo "Next steps:"
echo "1. Verify your state has been migrated by running 'terraform plan' in each directory"
echo "2. You can now delete the local terraform.tfstate and terraform.tfstate.backup files"
echo "3. Share the backend configuration with your team members"
