# Event Hub Monitoring - Terraform Deployment

Terraform infrastructure for monitoring Azure Event Hub ConsumerLag using native diagnostic logs.

## 📁 Project Structure

```
.
├── deploy/
│   ├── tf/                    # Production Terraform deployment
│   │   ├── main.tf           # Main infrastructure configuration
│   │   ├── migrate-state.sh  # Deployment script
│   │   └── setup-backend.sh  # Remote state setup (optional)
│   └── temp/                  # Benchmark/reference implementations
│       └── terraform/         # Example patterns
└── .devcontainer/             # Dev container for Terraform CLI
```

## 🚀 Quick Start

### Prerequisites
- Azure CLI installed and authenticated
- Terraform CLI (automatically available in devcontainer)
- Azure subscription with Event Hub namespace

### Deploy

1. **Navigate to deployment folder:**
   ```bash
   cd deploy/tf
   ```

2. **Run deployment script:**
   ```bash
   ./migrate-state.sh
   ```

   The script will:
   - Prompt for Azure login (if needed)
   - Ask for Resource Group name
   - Ask for Event Hub namespace name
   - Create `terraform.tfvars` with your inputs
   - Run `terraform init`, `plan`, and `apply`

### What Gets Deployed

✅ **Log Analytics Workspace** - Stores diagnostic logs  
✅ **Log Analytics Table** - Resource-specific table for Event Hub metrics  
✅ **Diagnostic Setting** - Sends ConsumerLag metrics to Log Analytics  

### Query ConsumerLag Metrics

Go to Azure Portal → Log Analytics Workspace → Logs, then run:

```kusto
AZMSApplicationMetricLogs
| where Name == "ConsumerLag"
| project TimeGenerated, ConsumerGroup, PartitionId, Total
| order by TimeGenerated desc
```

## 🛠️ Manual Terraform Commands

If you prefer manual control:

```bash
cd deploy/tf

# Initialize
terraform init

# Create terraform.tfvars manually
cat > terraform.tfvars <<EOF
subscription_id         = "your-subscription-id"
resource_group_name     = "your-resource-group"
eventhub_namespace_name = "your-eventhub-namespace"
EOF

# Plan and apply
terraform plan
terraform apply
```

## 🧹 Cleanup

To destroy all resources:

```bash
cd deploy/tf
terraform destroy
```

## 📚 Reference

- **deploy/temp/terraform/** - Contains benchmark Terraform patterns used as reference
- **Azure Diagnostic Logs** - Uses resource-specific mode (`log_analytics_destination_type = "Dedicated"`)
- **Table**: `AZMSApplicationMetricLogs` (dedicated Event Hub metrics table)

## 🔧 Remote State (Optional)

To use remote state storage:

1. Run setup script:
   ```bash
   cd deploy/tf
   ./setup-backend.sh
   ```

2. Uncomment backend block in `main.tf`

3. Run `terraform init` to migrate state

---

**Note**: This is a simplified Terraform-only deployment. For the full Java-based custom metrics emitter, see the original repository branches.
