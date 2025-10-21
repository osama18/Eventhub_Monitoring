# Eventhub_Monitoring

This project provides a comprehensive solution for monitoring Azure Event Hubs and overall system health. It includes Terraform configurations for infrastructure deployment and detailed design documentation for a robust observability strategy.

## 📁 Project Structure

```
.
├── .devcontainer/               # Dev container for Terraform + Azure CLI
├── deploy/
│   └── tf/                      # Terraform infrastructure for deployment
│       ├── main.tf
│       ├── deploy_local.sh
│       ├── deploy_remote.sh
│       └── README.md            # Detailed deployment instructions
└── docs/
    ├── observability-design.md  # Core observability design document
    └── kql-queries.md           # KQL queries for Log Analytics
```

## 📚 Documentation

- **[Observability Design (`docs/observability-design.md`)](docs/observability-design.md)**: This is the primary design document. It outlines the key risks, SLOs/SLIs, alerting strategy, and implementation details for monitoring the Event Hubs namespace.

- **[KQL Queries (`docs/kql-queries.md`)](docs/kql-queries.md)**: Contains a set of useful Kusto Query Language (KQL) queries to analyze consumer lag and other metrics in Log Analytics.

- **[Deployment Guide (`deploy/tf/README.md`)](deploy/tf/README.md)**: Provides detailed instructions on how to deploy the infrastructure using the provided Terraform scripts.


## Disclaimer

This project is not an official product. Always do your own research and testing before deploying to a production environment.