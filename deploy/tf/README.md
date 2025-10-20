# Terraform Deployment for Event Hub Monitoring

This directory contains the Terraform configuration for deploying the Azure resources required for Event Hub monitoring.

## 🚀 Quick Start

### Option 1: Local State Deployment

Best for single developer, simple projects. State is stored locally in `terraform.tfstate`.

```bash
./deploy_local.sh
```

### Option 2: Remote State Deployment (Recommended for Teams)

Best for team collaboration and production environments. State is stored securely in Azure Storage. The script handles the backend setup automatically.

```bash
./deploy_remote.sh
```

## 📋 What Gets Deployed

✅ **Log Analytics Workspace** - Stores diagnostic logs (PerGB2018, 30-day retention).  
✅ **Diagnostic Setting** - Sends Event Hubs diagnostic logs to Log Analytics.

## 🛠️ Manual Terraform Commands

All commands should be run from this directory.

### Local State

```bash
# 1. Initialize with local state
terraform init

# 2. Create variables file
cat > terraform.tfvars <<TFVARS
subscription_id         = "your-subscription-id"
resource_group_name     = "your-resource-group"
eventhub_namespace_name = "your-eventhub-namespace"
TFVARS

# 3. Plan and apply
terraform plan
terraform apply
```

### Remote State

```bash
# 1. Initialize with remote state
# The deploy_remote.sh script handles this, but for manual init:
terraform init 
  -backend-config="resource_group_name=<backend-rg-name>" 
  -backend-config="storage_account_name=<backend-storage-account-name>" 
  -backend-config="container_name=<backend-container-name>" 
  -backend-config="key=eventhub-monitoring/terraform.tfstate"

# 2. Create variables file
cat > terraform.tfvars <<TFVARS
subscription_id         = "your-subscription-id"
resource_group_name     = "your-resource-group"
eventhub_namespace_name = "your-eventhub-namespace"
TFVARS

# 3. Plan and apply
terraform plan
terraform apply
```

## 🧹 Cleanup

From this directory:

```bash
terraform destroy
```
