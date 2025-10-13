# Event Hub Monitoring - Terraform Deployment

Terraform infrastructure for monitoring Azure Event Hub ConsumerLag using native diagnostic logs.

## Project Structure

```
.
├── deploy/
│   ├── tf/
│   │   ├── local/               # Local state deployment
│   │   │   ├── main.tf         # Terraform config (no backend)
│   │   │   ├── deploy.sh       # Deployment script
│   │   │   └── README.md       # Local deployment guide
│   │   └── remote/              # Remote state deployment
│   │       ├── main.tf         # Terraform config (with backend)
│   │       ├── deploy.sh       # Deployment script (auto-creates backend)
│   │       └── README.md       # Remote deployment guide
│   └── temp/                    # Benchmark/reference implementations
│       └── terraform/           # Example patterns from team
└── .devcontainer/               # Dev container for Terraform + Azure CLI
```

## Quick Start

### Option 1: Local State (Default)

Best for single developer, simple projects.

```bash
cd deploy/tf/local
./deploy.sh
```

State stored in `terraform.tfstate` locally.

### Option 2: Remote State (Team Collaboration)

Best for team collaboration, production environments.

```bash
cd deploy/tf/remote
./deploy.sh
```

The script will:
- Prompt for Event Hub configuration
- Prompt for backend storage configuration
- **Automatically create backend storage** (if doesn't exist)
- Deploy with remote state

State stored in Azure Storage.

## What Gets Deployed

- **Log Analytics Workspace** - Stores diagnostic logs (PerGB2018, 30-day retention)  
- **Log Analytics Table** - Resource-specific table `AZMSApplicationMetricLogs`  
- **Diagnostic Setting** - Sends ConsumerLag metrics to Log Analytics (Dedicated mode)  

## Query ConsumerLag Metrics

Go to Azure Portal → Log Analytics Workspace → Logs, then run:

```kusto
// View all ConsumerLag metrics
AZMSApplicationMetricLogs
| where OperationName == "ConsumerLag"
```

**Note:** Data appears 5-15 minutes after consumers start reading messages. First-time ingestion can take up to 30 minutes.

## Manual Terraform Commands

### Local State

```bash
cd deploy/tf/local

terraform init

cat > terraform.tfvars <<TFVARS
subscription_id         = "your-subscription-id"
resource_group_name     = "your-resource-group"
eventhub_namespace_name = "your-eventhub-namespace"
TFVARS

terraform plan
terraform apply
```

### Remote State

```bash
cd deploy/tf/remote

# The deploy.sh script automatically handles backend setup
# Or run manually:

terraform init \
  -backend-config="resource_group_name=<BACKEND_RG>" \
  -backend-config="storage_account_name=<STORAGE_ACCOUNT>" \
  -backend-config="container_name=<CONTAINER>" \
  -backend-config="key=eventhub-monitoring/terraform.tfstate" \
  -backend-config="use_azuread_auth=true"

cat > terraform.tfvars <<TFVARS
subscription_id         = "your-subscription-id"
resource_group_name     = "your-resource-group"
eventhub_namespace_name = "your-eventhub-namespace"
TFVARS

terraform plan
terraform apply
```

**Note:** Requires **Storage Blob Data Contributor** role on the storage account for Azure AD authentication.

## Cleanup

```bash
cd deploy/tf/local  # or deploy/tf/remote
terraform destroy
```

---

**Note**: This is a simplified Terraform-only deployment. Project focuses solely on infrastructure deployment for Event Hub monitoring of consumer lag.
