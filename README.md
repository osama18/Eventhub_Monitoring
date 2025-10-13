# Event Hub Monitoring - Terraform Deployment

Terraform infrastructure for monitoring Azure Event Hub ConsumerLag using native diagnostic logs.

## 📁 Project Structure

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
│   │       ├── deploy.sh       # Deployment script
│   │       ├── setup-backend.sh # Backend setup
│   │       └── README.md       # Remote deployment guide
│   └── temp/                    # Benchmark/reference implementations
│       └── terraform/           # Example patterns from team
└── .devcontainer/               # Dev container for Terraform + Azure CLI
```

## 🚀 Quick Start

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

## 📋 What Gets Deployed

✅ **Log Analytics Workspace** - Stores diagnostic logs (PerGB2018, 30-day retention)  
✅ **Log Analytics Table** - Resource-specific table `AZMSApplicationMetricLogs`  
✅ **Diagnostic Setting** - Sends ConsumerLag metrics to Log Analytics (Dedicated mode)  

## 🔍 Query ConsumerLag Metrics

Go to Azure Portal → Log Analytics Workspace → Logs, then run:

```kusto
// View all ConsumerLag metrics
AZMSApplicationMetricLogs
| where Name == "ConsumerLag"
| project TimeGenerated, ConsumerGroup, PartitionId, Total
| order by TimeGenerated desc

// Aggregate by consumer group
AZMSApplicationMetricLogs
| where Name == "ConsumerLag"
| summarize AvgLag = avg(Total), MaxLag = max(Total) by ConsumerGroup
| order by AvgLag desc
```

## 🛠️ Manual Terraform Commands

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

# Setup backend first
./setup-backend.sh

# Edit main.tf backend block

terraform init

cat > terraform.tfvars <<TFVARS
subscription_id         = "your-subscription-id"
resource_group_name     = "your-resource-group"
eventhub_namespace_name = "your-eventhub-namespace"
TFVARS

terraform plan
terraform apply
```

## 🧹 Cleanup

```bash
cd deploy/tf/local  # or deploy/tf/remote
terraform destroy
```

## 📚 Reference

- **deploy/temp/terraform/** - Contains benchmark Terraform patterns from team (aks, fabric examples)
- **Azure Diagnostic Logs** - Uses resource-specific mode (`log_analytics_destination_type = "Dedicated"`)
- **Table**: `AZMSApplicationMetricLogs` (dedicated Event Hub metrics table, not AzureDiagnostics)
- **Pattern**: Single `main.tf` file with variables, provider, resources, outputs (matches team standard)

---

**Note**: This is a simplified Terraform-only deployment. Project focuses solely on infrastructure deployment for Event Hub monitoring.
