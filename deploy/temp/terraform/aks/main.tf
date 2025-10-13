terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
  }

  backend "azurerm" {
    resource_group_name  = "cdpp-infra"
    storage_account_name = "cdppterraformstate"
    container_name       = "tfstate"
    key                  = "aks/terraform.tfstate"
  }
}

provider "azurerm" {
  subscription_id = "fcde6cf3-f69d-4b81-9ae3-7c1187597de0"
  features {}
}

provider "azuread" {
  # Uses the same authentication as azurerm provider
}

# ==============================================================================
# AKS Cluster
# ==============================================================================

resource "azurerm_kubernetes_cluster" "cdpp_cluster" {
  name                      = "cdpp-cluster"
  location                  = "North Europe"
  resource_group_name       = "cdpp-infra"
  dns_prefix                = "cdpp-cluster"
  sku_tier                  = "Standard"
  kubernetes_version        = "1.33"
  cost_analysis_enabled     = true
  workload_identity_enabled = true
  oidc_issuer_enabled       = true
  default_node_pool {
    zones                        = ["2", "3"]
    name                         = "default"
    node_count                   = 3
    vm_size                      = "Standard_D4pds_v6"
    os_disk_type                 = "Ephemeral"
    os_disk_size_gb              = 220
    only_critical_addons_enabled = true # tainting the nodes with CriticalAddonsOnly=true:NoSchedule to avoid scheduling workloads on the system node pool
    temporary_name_for_rotation  = "temp"
    vnet_subnet_id               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdpp-infra/providers/Microsoft.Network/virtualNetworks/cdpp-poc-vnet/subnets/aks"
    upgrade_settings {
      drain_timeout_in_minutes      = 10
      max_surge                     = "33%"
      node_soak_duration_in_minutes = 0
    }
  }
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    pod_cidr            = "100.64.0.0/12"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
  }
  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.karpenter_identity.id]
  }
}

resource "azapi_update_resource" "nap" {
  type                    = "Microsoft.ContainerService/managedClusters@2025-07-01"
  resource_id             = azurerm_kubernetes_cluster.cdpp_cluster.id
  ignore_missing_property = true
  body = {
    properties = {
      nodeProvisioningProfile = {
        mode             = "Auto"
        defaultNodePools = "None"
      }
    }
  }
}

# ==============================================================================
# Managed Identities
# ==============================================================================

# Create user-assigned managed identity for ArgoCD
resource "azurerm_user_assigned_identity" "argocd_identity" {
  location            = "North Europe"
  name                = "argocd-identity"
  resource_group_name = "cdpp-infra"
}

# Create user-assigned managed identity for CubeJS
resource "azurerm_user_assigned_identity" "cubejs_identity" {
  location            = "North Europe"
  name                = "cubejs-identity"
  resource_group_name = "cdpp-infra"
}

# Create user-assigned managed identity for Karpenter
resource "azurerm_user_assigned_identity" "karpenter_identity" {
  location            = "North Europe"
  name                = "karpenter-identity"
  resource_group_name = "cdpp-infra"
}

# Create user-assigned managed identity for External Secrets
resource "azurerm_user_assigned_identity" "external_secrets_identity" {
  location            = "North Europe"
  name                = "external-secrets-identity"
  resource_group_name = "cdpp-infra"
}

# Create user-assigned managed identity for Personalize Service
resource "azurerm_user_assigned_identity" "personalize_identity" {
  location            = "North Europe"
  name                = "personalize-identity"
  resource_group_name = "cdpp-infra"
}

# Create user-assigned managed identity for the AEP Ingestion API
resource "azurerm_user_assigned_identity" "aep_ingestion_api_identity" {
  location            = "North Europe"
  name                = "aep-ingestion-api-identity"
  resource_group_name = "cdpp-infra"
}

# Create user-assigned managed identity for the AEP Ingestion API
resource "azurerm_user_assigned_identity" "streaming_etl_identity" {
  location            = "North Europe"
  name                = "streaming-etl-identity"
  resource_group_name = "cdpp-infra"
}

# Create user-assigned managed identity for Sessionization Service
resource "azurerm_user_assigned_identity" "sessionization_identity" {
  location            = "North Europe"
  name                = "sessionization-identity"
  resource_group_name = "cdpp-infra"
}

# Create user-assigned managed identity for Tenant Config Service
resource "azurerm_user_assigned_identity" "tenant_config_identity" {
  location            = "North Europe"
  name                = "tenant-config-identity"
  resource_group_name = "cdpp-infra"
}

# Create user-assigned managed identity for CDC consumer Service
resource "azurerm_user_assigned_identity" "cdc_consumer_identity" {
  location            = "North Europe"
  name                = "cdc-consumer-identity"
  resource_group_name = "cdpp-infra"
}

# Create user-assigned managed identity for ExternalDNS
resource "azurerm_user_assigned_identity" "external_dns_identity" {
  location            = "North Europe"
  name                = "external-dns-identity"
  resource_group_name = "cdpp-infra"
}

# Create user-assigned managed identity for Guest Context
resource "azurerm_user_assigned_identity" "guest_context_identity" {
  location            = "North Europe"
  name                = "guest-context-identity"
  resource_group_name = "cdpp-infra"
}

# Create user-assigned managed identity for Session Post Processing Service
resource "azurerm_user_assigned_identity" "session_post_processing_identity" {
  location            = "North Europe"
  name                = "session-post-processing-identity"
  resource_group_name = "cdpp-infra"
}

# Create user-assigned managed identity for Personalize Interactive Service
resource "azurerm_user_assigned_identity" "personalize_interactive_identity" {
  location            = "North Europe"
  name                = "personalize-interactive-identity"
  resource_group_name = "cdpp-infra"
}

# Create user-assigned managed identity for Personalize Analytics Service
resource "azurerm_user_assigned_identity" "personalize_analytics_identity" {
  location            = "North Europe"
  name                = "personalize-analytics-identity"
  resource_group_name = "cdpp-infra"
}

# ==============================================================================
# Federated Identity Credentials
# ==============================================================================

# Create federated identity credential for Personalize Service workload identity
resource "azurerm_federated_identity_credential" "personalize_federated_credential" {
  name                = "personalize-identity"
  resource_group_name = "cdpp-infra"
  parent_id           = azurerm_user_assigned_identity.personalize_identity.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.cdpp_cluster.oidc_issuer_url
  subject             = "system:serviceaccount:default:personalize-service"

  depends_on = [azurerm_user_assigned_identity.personalize_identity]
}

# Create federated identity credential for ArgoCD workload identity
resource "azurerm_federated_identity_credential" "argocd_federated_credential" {
  name                = "argocd-identity"
  resource_group_name = "cdpp-infra"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.cdpp_cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.argocd_identity.id
  subject             = "system:serviceaccount:argocd:argocd-repo-server"

  depends_on = [azurerm_user_assigned_identity.argocd_identity]
}

# Create federated identity credential for CubeJS workload identity
resource "azurerm_federated_identity_credential" "cubejs_federated_credential" {
  name                = "cubejs-identity"
  resource_group_name = "cdpp-infra"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.cdpp_cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.cubejs_identity.id
  subject             = "system:serviceaccount:default:cubejs"

  depends_on = [azurerm_user_assigned_identity.cubejs_identity]
}

# Create federated identity credential for External Secrets workload identity
resource "azurerm_federated_identity_credential" "external_secrets_federated_credential" {
  name                = "external-secrets-identity"
  resource_group_name = "cdpp-infra"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.cdpp_cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.external_secrets_identity.id
  subject             = "system:serviceaccount:kube-system:external-secrets"

  depends_on = [azurerm_user_assigned_identity.external_secrets_identity]
}

# Create federated identity credential for the AEP Ingestion API workload identity
resource "azurerm_federated_identity_credential" "aep_ingestion_api_federated_credential" {
  name                = "aep-ingestion-api-identity"
  resource_group_name = "cdpp-infra"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.cdpp_cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.aep_ingestion_api_identity.id
  subject             = "system:serviceaccount:default:aep-ingestion-api"

  depends_on = [azurerm_user_assigned_identity.aep_ingestion_api_identity]
}

# Create federated identity credential for Streaming ETL Service workload identity
resource "azurerm_federated_identity_credential" "streaming_etl_federated_credential" {
  name                = "streaming-etl-identity"
  resource_group_name = "cdpp-infra"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.cdpp_cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.streaming_etl_identity.id
  subject             = "system:serviceaccount:default:streaming-etl-service"

  depends_on = [azurerm_user_assigned_identity.streaming_etl_identity]
}

# Create federated identity credential for Sessionization Service workload identity
resource "azurerm_federated_identity_credential" "sessionization_federated_credential" {
  name                = "sessionization-identity"
  resource_group_name = "cdpp-infra"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.cdpp_cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.sessionization_identity.id
  subject             = "system:serviceaccount:default:sessionization-service"

  depends_on = [azurerm_user_assigned_identity.sessionization_identity]
}

# Create federated identity credential for Tenant Config Service workload identity
resource "azurerm_federated_identity_credential" "tenant_config_federated_credential" {
  name                = "tenant-config-identity"
  resource_group_name = "cdpp-infra"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.cdpp_cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.tenant_config_identity.id
  subject             = "system:serviceaccount:default:tenant-config-service"

  depends_on = [azurerm_user_assigned_identity.tenant_config_identity]
}

# Create federated identity credential for cdc consumer Service identity
resource "azurerm_federated_identity_credential" "cdc_consumer_federated_credential" {
  name                = "cdc-consumer-identity"
  resource_group_name = "cdpp-infra"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.cdpp_cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.cdc_consumer_identity.id
  subject             = "system:serviceaccount:default:cdc-consumer-service"

  depends_on = [azurerm_user_assigned_identity.cdc_consumer_identity]
}


# Create federated identity credential for GitHub Actions to use CDC consumer identity
resource "azurerm_federated_identity_credential" "cdc_consumer_github_federated_credential" {
  name                = "cdc-consumer-github-identity"
  resource_group_name = "cdpp-infra"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  parent_id           = azurerm_user_assigned_identity.cdc_consumer_identity.id
  subject             = "repo:Sitecore-CDPP/sitecore.cdppshared.cosmoscdcconsumer:environment:github-azure-env"

  depends_on = [azurerm_user_assigned_identity.cdc_consumer_identity]
}


# Create federated identity credential for ExternalDNS workload identity
resource "azurerm_federated_identity_credential" "external_dns_federated_credential" {
  name                = "external-dns-identity"
  resource_group_name = "cdpp-infra"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.cdpp_cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.external_dns_identity.id
  subject             = "system:serviceaccount:kube-system:external-dns"

  depends_on = [azurerm_user_assigned_identity.external_dns_identity]
}

# Create federated identity credential for Guest Context workload identity
resource "azurerm_federated_identity_credential" "guest_context_identity_federated_credential" {
  name                = "guest-context-identity"
  resource_group_name = "cdpp-infra"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.cdpp_cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.guest_context_identity.id
  subject             = "system:serviceaccount:default:guest-context-service"

  depends_on = [azurerm_user_assigned_identity.guest_context_identity]
}

# Create federated identity credential for Session Post Processing Service workload identity
resource "azurerm_federated_identity_credential" "session_post_processing_federated_credential" {
  name                = "session-post-processing-identity"
  resource_group_name = "cdpp-infra"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.cdpp_cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.session_post_processing_identity.id
  subject             = "system:serviceaccount:default:session-post-processing-service"

  depends_on = [azurerm_user_assigned_identity.session_post_processing_identity]
}

# Create federated identity credential for Personalize Interactive Service workload identity
resource "azurerm_federated_identity_credential" "personalize_interactive_federated_credential" {
  name                = "personalize-interactive-identity"
  resource_group_name = "cdpp-infra"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.cdpp_cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.personalize_interactive_identity.id
  subject             = "system:serviceaccount:default:personalize-interactive-service"

  depends_on = [azurerm_user_assigned_identity.personalize_interactive_identity]
}

# Create federated identity credential for Personalize Analytics Service workload identity
resource "azurerm_federated_identity_credential" "personalize_analytics_federated_credential" {
  name                = "personalize-analytics-identity"
  resource_group_name = "cdpp-infra"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.cdpp_cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.personalize_analytics_identity.id
  subject             = "system:serviceaccount:default:personalize-analytics-service"

  depends_on = [azurerm_user_assigned_identity.personalize_analytics_identity]
}

# ==============================================================================
# Custom Roles
# ==============================================================================

# Custom Cosmos DB SQL Role Contributor
resource "azurerm_cosmosdb_sql_role_definition" "cosmosdb_data_contributor_role" {
  name                = "Cosmos DB SQL Contributor Role"
  resource_group_name = "cosmos-db"
  account_name        = "lopr-cosmos"
  type                = "CustomRole"
  assignable_scopes = [
    "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/lopr-cosmos"
  ]
  permissions {
    data_actions = [
      "Microsoft.DocumentDB/databaseAccounts/readMetadata",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*"
    ]
  }
}

# Custom Cosmos DB SQL Role Contributor for cdpp-poc-cosmos account name
resource "azurerm_cosmosdb_sql_role_definition" "cosmosdb_data_contributor_role_cdpp_poc_cosmos" {
  name                = "Cosmos DB SQL Contributor Role CDP POC"
  resource_group_name = "cosmos-db"
  account_name        = "cdpp-poc-cosmos"
  type                = "CustomRole"
  assignable_scopes = [
    "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/cdpp-poc-cosmos"
  ]
  permissions {
    data_actions = [
      "Microsoft.DocumentDB/databaseAccounts/readMetadata",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*"
    ]
  }
}

# ==============================================================================
# External Entra ID Group (from another tenant)
# ==============================================================================

# Data source to reference the CDPP Engineers group from another tenant
data "azuread_group" "cdpp_engineers_group" {
  object_id = "fedb515e-4ce5-4642-b3e9-788776198449" # GRP - CDPP Engineers
}

# ==============================================================================
# Role Assignments
# ==============================================================================

# Assign AcrPull role to AKS cluster for pulling container images
resource "azurerm_role_assignment" "cdpp_cluster_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.cdpp_cluster.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdpp-infra/providers/Microsoft.ContainerRegistry/registries/acrcdpp"
  skip_service_principal_aad_check = true
}

# Assign AcrPull role to ArgoCD identity for pulling Helm charts
resource "azurerm_role_assignment" "argocd_acr_pull" {
  principal_id                     = azurerm_user_assigned_identity.argocd_identity.principal_id
  role_definition_name             = "AcrPull"
  scope                            = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdpp-infra/providers/Microsoft.ContainerRegistry/registries/acrcdpp"
  skip_service_principal_aad_check = true

  depends_on = [azurerm_user_assigned_identity.argocd_identity]
}

# Assign Network Contributor role to Karpenter identity for the AKS managed cluster resource group
resource "azurerm_role_assignment" "karpenter_network_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdpp-infra/providers/Microsoft.Network/virtualNetworks/cdpp-poc-vnet"
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.karpenter_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.karpenter_identity]
}

# Assign Key Vault Secrets User role to External Secrets identity for accessing secrets
resource "azurerm_role_assignment" "external_secrets_key_vault_secrets_user" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdpp-infra/providers/Microsoft.KeyVault/vaults/cloudflare-secrets"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.external_secrets_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.external_secrets_identity]
}

# Assign Key Vault Secrets User role to External Secrets identity for accessing secrets
resource "azurerm_role_assignment" "external_secrets_locust_key_vault_secrets_user" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/CDP-Analytics-PoC/providers/Microsoft.KeyVault/vaults/azure-loadtests"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.external_secrets_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.external_secrets_identity]
}


# Personalize service section
#
# Assign Key Vault Secrets User role to Personalize identity for accessing secrets
resource "azurerm_role_assignment" "personalize_key_vault_secrets_user" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdpp-infra/providers/Microsoft.KeyVault/vaults/personalize-aep-poc"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.personalize_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.personalize_identity]
}

# Assign Key Vault Secrets User role to Personalize Interactive identity for accessing secrets
resource "azurerm_role_assignment" "personalize_interactive_key_vault_secrets_user" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdpp-infra/providers/Microsoft.KeyVault/vaults/personalize-aep-poc"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.personalize_interactive_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.personalize_interactive_identity]
}

# Assign Key Vault Secrets User role to Personalize Analytics identity for accessing secrets
resource "azurerm_role_assignment" "personalize_analytics_key_vault_secrets_user" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdpp-infra/providers/Microsoft.KeyVault/vaults/personalize-aep-poc"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.personalize_analytics_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.personalize_analytics_identity]
}

# Assign Storage Blob Data Reader role to Personalize Interactive identity for cdp-poc resource group
resource "azurerm_role_assignment" "personalize_interactive_storage_blob_reader" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc"
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.personalize_interactive_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.personalize_interactive_identity]
}

#
# Personalize service section end
#

# AEP Ingestion API section
#
# Assign Key Vault Secrets User role to the AEP Ingestion API identity for accessing secrets
resource "azurerm_role_assignment" "aep_ingestion_api_key_vault_secrets_user" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc/providers/Microsoft.KeyVault/vaults/apostolosvault"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.aep_ingestion_api_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.aep_ingestion_api_identity]
}

resource "azurerm_role_assignment" "guest_profile_key_vault_secrets_user" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc/providers/Microsoft.KeyVault/vaults/apostolosvault"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.guest_context_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.guest_context_identity]
}

# Allows the AEP Ingestion API to manage storage accounts, read, write to blobs, and list containers
resource "azurerm_role_assignment" "aep_ingestion_api_storage_blob_data_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.aep_ingestion_api_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.aep_ingestion_api_identity]
}

# Allows cosmos dbs management operations
resource "azurerm_role_assignment" "aep_ingestion_api_cosmosdb_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db"
  role_definition_name = "DocumentDB Account Contributor"
  principal_id         = azurerm_user_assigned_identity.aep_ingestion_api_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.aep_ingestion_api_identity]
}

# Assign Custom Cosmos DB Data Contributor role to the AEP Ingestion API identity
resource "azurerm_cosmosdb_sql_role_assignment" "aep_ingestion_api_cosmosdb_data_contributor" {
  resource_group_name = "cosmos-db"
  account_name        = "lopr-cosmos"
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role.id
  principal_id        = azurerm_user_assigned_identity.aep_ingestion_api_identity.principal_id
  scope               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/lopr-cosmos"

  depends_on = [
    azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role,
    azurerm_user_assigned_identity.aep_ingestion_api_identity
  ]
}

# Assign Custom Cosmos DB Data Contributor cdpp-poc-cosmos role to the AEP Ingestion API identity
resource "azurerm_cosmosdb_sql_role_assignment" "aep_ingestion_api_cosmosdb_data_contributor_cdpp_poc" {
  resource_group_name = "cosmos-db"
  account_name        = "cdpp-poc-cosmos"
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role_cdpp_poc_cosmos.id
  principal_id        = azurerm_user_assigned_identity.aep_ingestion_api_identity.principal_id
  scope               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/cdpp-poc-cosmos"

  depends_on = [
    azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role_cdpp_poc_cosmos,
    azurerm_user_assigned_identity.aep_ingestion_api_identity
  ]
}

# Assign Event Hubs Data Owner role to AEP Ingestion API identity for Event Hub access cdp-event-ingestion-log
resource "azurerm_role_assignment" "aep_ingestion_api_eventhub_data_owner" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc/providers/Microsoft.EventHub/namespaces/sc-cdp-poc/eventhubs/cdp-event-ingestion-log"
  role_definition_name = "Azure Event Hubs Data Owner"
  principal_id         = azurerm_user_assigned_identity.aep_ingestion_api_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.aep_ingestion_api_identity]
}

# Assign Event Hubs Data Owner role to AEP Ingestion API identity for Event Hub access cdp-guests-changelog
resource "azurerm_role_assignment" "aep_ingestion_api_eventhub_cdp_sessions_changelog" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc/providers/Microsoft.EventHub/namespaces/sc-cdp-poc/eventhubs/cdp-guests-changelog"
  role_definition_name = "Azure Event Hubs Data Owner"
  principal_id         = azurerm_user_assigned_identity.aep_ingestion_api_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.aep_ingestion_api_identity]
}

#
# AEP Ingestion API section end
#

# Tenant Config service section
#
# Assign Key Vault Secrets User role to Tenant Config identity for accessing secrets
resource "azurerm_role_assignment" "tenant_config_key_vault_secrets_user" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc/providers/Microsoft.KeyVault/vaults/apostolosvault"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.tenant_config_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.tenant_config_identity]
}

# Allows tenant config service to manage storage accounts, read, write to blobs, and list containers
resource "azurerm_role_assignment" "tenant_config_storage_blob_data_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.tenant_config_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.tenant_config_identity]
}

# Allows cosmos dbs management operations
resource "azurerm_role_assignment" "tenant_config_cosmosdb_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db"
  role_definition_name = "DocumentDB Account Contributor"
  principal_id         = azurerm_user_assigned_identity.tenant_config_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.tenant_config_identity]
}

# Assign Custom Cosmos DB Data Contributor role to Tenant Config identity
resource "azurerm_cosmosdb_sql_role_assignment" "tenant_config_cosmosdb_data_contributor" {
  resource_group_name = "cosmos-db"
  account_name        = "lopr-cosmos"
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role.id
  principal_id        = azurerm_user_assigned_identity.tenant_config_identity.principal_id
  scope               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/lopr-cosmos"

  depends_on = [
    azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role,
    azurerm_user_assigned_identity.tenant_config_identity
  ]
}

# Assign Custom Cosmos DB Data Contributor cdpp-poc-cosmos role to Tenant Config identity
resource "azurerm_cosmosdb_sql_role_assignment" "tenant_config_cosmosdb_data_contributor_cdpp_poc" {
  resource_group_name = "cosmos-db"
  account_name        = "cdpp-poc-cosmos"
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role_cdpp_poc_cosmos.id
  principal_id        = azurerm_user_assigned_identity.tenant_config_identity.principal_id
  scope               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/cdpp-poc-cosmos"

  depends_on = [
    azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role_cdpp_poc_cosmos,
    azurerm_user_assigned_identity.tenant_config_identity
  ]
}

#
# Tenant Config service section end
#

# Stream ETL service section
#
# Assign Key Vault Secrets User role to Streaming ETL identity for accessing secrets
resource "azurerm_role_assignment" "streaming_etl_key_vault_secrets_user" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc/providers/Microsoft.KeyVault/vaults/apostolosvault"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.streaming_etl_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.streaming_etl_identity]
}

# Allows Streaming ETL service to manage storage accounts, read, write to blobs, and list containers
resource "azurerm_role_assignment" "streaming_etl_storage_blob_data_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.streaming_etl_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.streaming_etl_identity]
}

# Allows cosmos dbs management operations to Streaming ETL
resource "azurerm_role_assignment" "streaming_etl_cosmosdb_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db"
  role_definition_name = "DocumentDB Account Contributor"
  principal_id         = azurerm_user_assigned_identity.streaming_etl_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.streaming_etl_identity]
}

# Assign Custom Cosmos DB Data Contributor role to Streaming ETL identity
resource "azurerm_cosmosdb_sql_role_assignment" "streaming_etl_cosmosdb_data_contributor" {
  resource_group_name = "cosmos-db"
  account_name        = "lopr-cosmos"
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role.id
  principal_id        = azurerm_user_assigned_identity.streaming_etl_identity.principal_id
  scope               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/lopr-cosmos"

  depends_on = [
    azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role,
    azurerm_user_assigned_identity.streaming_etl_identity
  ]
}

# Assign Custom Cosmos DB Data Contributor cdpp-poc-cosmos role to Streaming ETL identity
resource "azurerm_cosmosdb_sql_role_assignment" "streaming_etl_cosmosdb_data_contributor_cdpp_poc" {
  resource_group_name = "cosmos-db"
  account_name        = "cdpp-poc-cosmos"
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role_cdpp_poc_cosmos.id
  principal_id        = azurerm_user_assigned_identity.streaming_etl_identity.principal_id
  scope               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/cdpp-poc-cosmos"

  depends_on = [
    azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role_cdpp_poc_cosmos,
    azurerm_user_assigned_identity.streaming_etl_identity
  ]
}

# Assign Event Hubs Data Owner role to Streaming ETL identity for Event Hub access
resource "azurerm_role_assignment" "streaming_etl_eventhub_data_owner" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc/providers/Microsoft.EventHub/namespaces/sc-cdp-poc/eventhubs/cdp-sessionized-event-log"
  role_definition_name = "Azure Event Hubs Data Owner"
  principal_id         = azurerm_user_assigned_identity.streaming_etl_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.streaming_etl_identity]
}

# Allows sessionization service to manage storage accounts, read, write to blobs, and list containers
resource "azurerm_role_assignment" "streaming_etl_snapshot_storage_blob_data_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/AzureBackupRG_northeurope_1"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.streaming_etl_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.streaming_etl_identity]
}

#
# Streaming ETL service section end
#


#
# Sessionization service section
#

# Allows sessionization service to manage storage accounts, read, write to blobs, and list containers
resource "azurerm_role_assignment" "sessionization_storage_blob_tenantsettings_data_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.sessionization_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.sessionization_identity]
}

# Allows sessionization service to manage storage accounts, read, write to blobs, and list containers
resource "azurerm_role_assignment" "sessionization_storage_blob_eventhub_data_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/AzureBackupRG_northeurope_1"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.sessionization_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.sessionization_identity]
}

# Allows sessionization service to manage storage accounts, read, write to blobs, and list containers
resource "azurerm_role_assignment" "sessionization_eventhub_data_owner" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc"
  role_definition_name = "Azure Event Hubs Data Owner"
  principal_id         = azurerm_user_assigned_identity.sessionization_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.sessionization_identity]
}


# Assign Customblob Cosmos DB Data Contributor role to Sessionization identity
resource "azurerm_cosmosdb_sql_role_assignment" "sessionization_cosmosdb_data_contributor" {
  resource_group_name = "cosmos-db"
  account_name        = "lopr-cosmos"
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role.id
  principal_id        = azurerm_user_assigned_identity.sessionization_identity.principal_id
  scope               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/lopr-cosmos"

  depends_on = [
    azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role,
    azurerm_user_assigned_identity.sessionization_identity
  ]
}

#
# Sessionization service section end
#


#
# CDC consumer service section
#

# Assign Customblob Cosmos DB Data Contributor role to Cdc consumer identity
resource "azurerm_cosmosdb_sql_role_assignment" "cdc_consumer_cosmosdb_data_contributor" {
  resource_group_name = "cosmos-db"
  account_name        = "lopr-cosmos"
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role.id
  principal_id        = azurerm_user_assigned_identity.cdc_consumer_identity.principal_id
  scope               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/lopr-cosmos"

  depends_on = [
    azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role,
    azurerm_user_assigned_identity.cdc_consumer_identity
  ]
}

# Assign DocumentDB Account Contributor role to Cdc consumer identity
resource "azurerm_role_assignment" "cdc_consumer_cosmosdb_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db"
  role_definition_name = "DocumentDB Account Contributor"
  principal_id         = azurerm_user_assigned_identity.cdc_consumer_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.cdc_consumer_identity]
}

# Assign Event Hubs Data Owner role to Cdc consumer identity for Event Hub access cdp-session-closed-changelog
resource "azurerm_role_assignment" "cdc_consumer_eventhub_data_owner" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc/providers/Microsoft.EventHub/namespaces/sc-cdp-poc/eventhubs/cdp-session-closed-changelog"
  role_definition_name = "Azure Event Hubs Data Owner"
  principal_id         = azurerm_user_assigned_identity.cdc_consumer_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.cdc_consumer_identity]
}

#
# CDC consumer service section end
#

#
# Guest Context/Profile service section start
#

# Assign Storage Blob Data Reader role to Guest Context identity for accessing blobs
resource "azurerm_role_assignment" "guest_context_identity_storage_blob_reader" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc"
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.guest_context_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.guest_context_identity]
}

# Assign Custom Cosmos DB Data Contributor role to Guest Context identity for lopr-cosmos
resource "azurerm_cosmosdb_sql_role_assignment" "guest_context_identity_cosmosdb_data_contributor" {
  resource_group_name = "cosmos-db"
  account_name        = "lopr-cosmos"
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role.id
  principal_id        = azurerm_user_assigned_identity.guest_context_identity.principal_id
  scope               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/lopr-cosmos"

  depends_on = [
    azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role,
    azurerm_user_assigned_identity.guest_context_identity
  ]
}

# Assign Custom Cosmos DB Data Contributor role to Guest Context identity for cdpp-poc-cosmos
resource "azurerm_cosmosdb_sql_role_assignment" "guest_context_identity_cosmosdb_data_contributor_cdpp_poc" {
  resource_group_name = "cosmos-db"
  account_name        = "cdpp-poc-cosmos"
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role_cdpp_poc_cosmos.id
  principal_id        = azurerm_user_assigned_identity.guest_context_identity.principal_id
  scope               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/cdpp-poc-cosmos"

  depends_on = [
    azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role_cdpp_poc_cosmos,
    azurerm_user_assigned_identity.guest_context_identity
  ]
}

#
# Guest Context/Profile service section end
#

#
# Session Post Processing service section start
#
# Assign Key Vault Secrets User role to Session Post Processing identity for accessing secrets
resource "azurerm_role_assignment" "session_post_processing_key_vault_secrets_user" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc/providers/Microsoft.KeyVault/vaults/apostolosvault"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.session_post_processing_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.session_post_processing_identity]
}

# Allows Session Post Processing service to manage storage accounts, read, write to blobs, and list containers
resource "azurerm_role_assignment" "session_post_processing_storage_blob_data_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.session_post_processing_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.session_post_processing_identity]
}

# Allows cosmos dbs management operations to Session Post Processing Identity
resource "azurerm_role_assignment" "session_post_processing_cosmosdb_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db"
  role_definition_name = "DocumentDB Account Contributor"
  principal_id         = azurerm_user_assigned_identity.session_post_processing_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.session_post_processing_identity]
}

# Assign Custom Cosmos DB Data Contributor role to Session Post Processing identity
resource "azurerm_cosmosdb_sql_role_assignment" "session_post_processing_cosmosdb_data_contributor" {
  resource_group_name = "cosmos-db"
  account_name        = "lopr-cosmos"
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role.id
  principal_id        = azurerm_user_assigned_identity.session_post_processing_identity.principal_id
  scope               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/lopr-cosmos"

  depends_on = [
    azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role,
    azurerm_user_assigned_identity.session_post_processing_identity
  ]
}

# Assign Custom Cosmos DB Data Contributor cdpp-poc-cosmos role to Session Post Processing identity
resource "azurerm_cosmosdb_sql_role_assignment" "session_post_processing_cosmosdb_data_contributor_cdpp_poc" {
  resource_group_name = "cosmos-db"
  account_name        = "cdpp-poc-cosmos"
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role_cdpp_poc_cosmos.id
  principal_id        = azurerm_user_assigned_identity.session_post_processing_identity.principal_id
  scope               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/cdpp-poc-cosmos"

  depends_on = [
    azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role_cdpp_poc_cosmos,
    azurerm_user_assigned_identity.session_post_processing_identity
  ]
}

# Assign Event Hubs Data Owner role to Session Post Processing identity for Event Hub access cdp-session-closed-changelog
resource "azurerm_role_assignment" "session_post_processing_eventhub_data_owner" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc/providers/Microsoft.EventHub/namespaces/sc-cdp-poc/eventhubs/cdp-session-closed-changelog"
  role_definition_name = "Azure Event Hubs Data Owner"
  principal_id         = azurerm_user_assigned_identity.session_post_processing_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.session_post_processing_identity]
}

# Assign Event Hubs Data Owner role to Session Post Processing identity for Event Hub access cdp-sessions-changelog
resource "azurerm_role_assignment" "session_post_processing_eventhub_cdp_sessions_changelog" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc/providers/Microsoft.EventHub/namespaces/sc-cdp-poc/eventhubs/cdp-sessions-changelog"
  role_definition_name = "Azure Event Hubs Data Owner"
  principal_id         = azurerm_user_assigned_identity.session_post_processing_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.session_post_processing_identity]
}

# Assign Event Hubs Data Owner role to Session Post Processing identity for Event Hub access cdp-guests-changelog
resource "azurerm_role_assignment" "session_post_processing_eventhub_cdp_guests_changelog" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc/providers/Microsoft.EventHub/namespaces/sc-cdp-poc/eventhubs/cdp-guests-changelog"
  role_definition_name = "Azure Event Hubs Data Owner"
  principal_id         = azurerm_user_assigned_identity.session_post_processing_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.session_post_processing_identity]
}

# Allows Session Post Processing Identity to manage storage accounts, read, write to blobs, and list containers
resource "azurerm_role_assignment" "session_post_processing_snapshot_storage_blob_data_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/AzureBackupRG_northeurope_1"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.session_post_processing_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.session_post_processing_identity]
}
#
# Session Post Processing service section end
#

# ==============================================================================
# ExternalDNS Permissions
# ==============================================================================

# Assign Private DNS Zone Contributor role to ExternalDNS identity for managing DNS records
resource "azurerm_role_assignment" "external_dns_dns_zone_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdpp-infra/providers/Microsoft.Network/privateDnsZones/cdpps.internal"
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.external_dns_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.external_dns_identity]
}

# Assign Reader role to ExternalDNS identity for reading the resource group containing the DNS zone
resource "azurerm_role_assignment" "external_dns_reader" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdpp-infra"
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.external_dns_identity.principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_user_assigned_identity.external_dns_identity]
}

# ==============================================================================
# CDPP Engineers Group Role Assignments
# ==============================================================================

# Assign Custom Cosmos DB Data Contributor role (lopr-cosmos) to CDPP Engineers Group
resource "azurerm_cosmosdb_sql_role_assignment" "cdpp_engineers_cosmosdb_data_contributor_lopr" {
  resource_group_name = "cosmos-db"
  account_name        = "lopr-cosmos"
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role.id
  principal_id        = data.azuread_group.cdpp_engineers_group.object_id
  scope               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/lopr-cosmos"

  depends_on = [
    azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role,
    data.azuread_group.cdpp_engineers_group
  ]
}

# Assign Custom Cosmos DB Data Contributor role (cdpp-poc-cosmos) to CDPP Engineers Group
resource "azurerm_cosmosdb_sql_role_assignment" "cdpp_engineers_cosmosdb_data_contributor_cdpp_poc" {
  resource_group_name = "cosmos-db"
  account_name        = "cdpp-poc-cosmos"
  role_definition_id  = azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role_cdpp_poc_cosmos.id
  principal_id        = data.azuread_group.cdpp_engineers_group.object_id
  scope               = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cosmos-db/providers/Microsoft.DocumentDB/databaseAccounts/cdpp-poc-cosmos"

  depends_on = [
    azurerm_cosmosdb_sql_role_definition.cosmosdb_data_contributor_role_cdpp_poc_cosmos,
    data.azuread_group.cdpp_engineers_group
  ]
}

# Assign Custom Cosmos Storage Blob Data Contributor role (cdpp-poc) to CDPP Engineers Group
resource "azurerm_role_assignment" "cdpp_engineers_storage_blob_tenantsettings_data_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_group.cdpp_engineers_group.object_id
  principal_type       = "Group"

  depends_on = [data.azuread_group.cdpp_engineers_group]
}

# Assign Custom Cosmos Storage Blob Data Contributor role (AzureBackupRG_northeurope_1) to CDPP Engineers Group
resource "azurerm_role_assignment" "cdpp_engineers_storage_blob_eventhub_data_contributor" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/AzureBackupRG_northeurope_1"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_group.cdpp_engineers_group.object_id
  principal_type       = "Group"

  depends_on = [data.azuread_group.cdpp_engineers_group]
}

# Assign Custom Azure Event Hubs Data Owner role (cdp-poc) to CDPP Engineers Group
resource "azurerm_role_assignment" "cdpp_engineers_eventhub_data_owner" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc"
  role_definition_name = "Azure Event Hubs Data Owner"
  principal_id         = data.azuread_group.cdpp_engineers_group.object_id
  principal_type       = "Group"

  depends_on = [data.azuread_group.cdpp_engineers_group]
}

# Assign Key Vault Administrator role to CDPP Engineers Group for apostolosvault
resource "azurerm_role_assignment" "cdpp_engineers_key_vault_administrator_apostolos" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc/providers/Microsoft.KeyVault/vaults/apostolosvault"
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azuread_group.cdpp_engineers_group.object_id
  principal_type       = "Group"

  depends_on = [data.azuread_group.cdpp_engineers_group]
}

# Assign Key Vault Administrator role to CDPP Engineers Group for aep-provisioning-vault
resource "azurerm_role_assignment" "cdpp_engineers_key_vault_administrator_aep_provisioning" {
  scope                = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdp-poc/providers/Microsoft.KeyVault/vaults/aep-provisioning-vault"
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azuread_group.cdpp_engineers_group.object_id
  principal_type       = "Group"

  depends_on = [data.azuread_group.cdpp_engineers_group]
}

# ==============================================================================
# Outputs
# ==============================================================================

# ArgoCD Identity outputs
output "argocd_identity_client_id" {
  description = "Client ID of the ArgoCD managed identity"
  value       = azurerm_user_assigned_identity.argocd_identity.client_id
}

# CubeJS Identity outputs
output "cubejs_identity_client_id" {
  description = "Client ID of the CubeJS managed identity"
  value       = azurerm_user_assigned_identity.cubejs_identity.client_id
}

# Karpenter Identity outputs
output "karpenter_identity_client_id" {
  description = "Client ID of the Karpenter managed identity"
  value       = azurerm_user_assigned_identity.karpenter_identity.client_id
}

# Personalize Identity outputs
output "personalize_identity_client_id" {
  description = "Client ID of the Personalize managed identity"
  value       = azurerm_user_assigned_identity.personalize_identity.client_id
}

# AEP Ingestion API Identity outputs
output "aep_ingestion_api_identity_client_id" {
  description = "Client ID of the AEP Ingestion API managed identity"
  value       = azurerm_user_assigned_identity.aep_ingestion_api_identity.client_id
}

# Streaming ETL Identity outputs
output "streaming_etl_identity_client_id" {
  description = "Client ID of the Streaming ETL managed identity"
  value       = azurerm_user_assigned_identity.streaming_etl_identity.client_id
}

# Network outputs
output "alb_subnet_id" {
  description = "Resource ID of the ALB subnet for use in Kubernetes ApplicationLoadBalancer resources"
  value       = "/subscriptions/fcde6cf3-f69d-4b81-9ae3-7c1187597de0/resourceGroups/cdpp-infra/providers/Microsoft.Network/virtualNetworks/cdpp-poc-vnet/subnets/agfc-external"
}

# AEP Ingestion API Identity outputs
output "sessionization_identity_client_id" {
  description = "Client ID of the Sessionization managed identity"
  value       = azurerm_user_assigned_identity.sessionization_identity.client_id
}

# Tenant Config Identity outputs
output "tenant_config_identity_client_id" {
  description = "Client ID of the Tenant Config managed identity"
  value       = azurerm_user_assigned_identity.tenant_config_identity.client_id
}

# cdc consumer Identity outputs
output "cdc_consumer_identity_client_id" {
  description = "Client ID of the CDC Consumer managed identity"
  value       = azurerm_user_assigned_identity.cdc_consumer_identity.client_id
}

# ExternalDNS Identity outputs
output "external_dns_identity_client_id" {
  description = "Client ID of the ExternalDNS managed identity"
  value       = azurerm_user_assigned_identity.external_dns_identity.client_id
}

# Guest Context Identity outputs
output "guest_context_identity_client_id" {
  description = "Client ID of the Guest Context managed identity"
  value       = azurerm_user_assigned_identity.guest_context_identity.client_id
}

# CDPP Engineers Group outputs
output "cdpp_engineers_group_object_id" {
  description = "Object ID of the CDPP Engineers Entra ID group"
  value       = data.azuread_group.cdpp_engineers_group.object_id
}

output "cdpp_engineers_group_display_name" {
  description = "Display name of the CDPP Engineers Entra ID group"
  value       = data.azuread_group.cdpp_engineers_group.display_name
}

# Session Post Processing Identity outputs
output "session_post_processing_identity_client_id" {
  description = "Client ID of the Session Post Processing managed identity"
  value       = azurerm_user_assigned_identity.session_post_processing_identity.client_id
}

# Personalize Interactive Identity outputs
output "personalize_interactive_identity_client_id" {
  description = "Client ID of the Personalize Interactive managed identity"
  value       = azurerm_user_assigned_identity.personalize_interactive_identity.client_id
}

# Personalize Analytics Identity outputs
output "personalize_analytics_identity_client_id" {
  description = "Client ID of the Personalize Analytics managed identity"
  value       = azurerm_user_assigned_identity.personalize_analytics_identity.client_id
}
