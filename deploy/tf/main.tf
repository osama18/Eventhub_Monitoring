terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

# ==============================================================================
# Variables
# ==============================================================================

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "eventhub_namespace_name" {
  type        = string
  description = "Name of the EXISTING Event Hub namespace to monitor"
}

variable "diagnostic_eventhub_namespace_name" {
  type        = string
  default     = ""
  description = "Name of the NEW Event Hub namespace for diagnostic logs (auto-generated if not provided)"
}

variable "enable_log_analytics" {
  type        = bool
  default     = true
  description = "Enable Log Analytics workspace destination for diagnostic logs"
}

variable "enable_storage_account" {
  type        = bool
  default     = false
  description = "Enable Storage Account archiving for diagnostic logs"
}

variable "enable_eventhub_streaming" {
  type        = bool
  default     = false
  description = "Enable Event Hub streaming for diagnostic logs"
}

variable "storage_account_name" {
  type        = string
  default     = ""
  description = "Name of the storage account (auto-generated if not provided)"
}

# ==============================================================================
# Provider
# ==============================================================================

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
  storage_use_azuread = true
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

# Reference to EXISTING Event Hub namespace that we want to monitor
data "azurerm_eventhub_namespace" "monitored" {
  name                = var.eventhub_namespace_name
  resource_group_name = data.azurerm_resource_group.this.name
}

# ==============================================================================
# NEW Event Hub Namespace for Diagnostic Logs
# ==============================================================================

resource "random_string" "eventhub_suffix" {
  count   = var.enable_eventhub_streaming ? 1 : 0
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_eventhub_namespace" "diagnostic" {
  count               = var.enable_eventhub_streaming ? 1 : 0
  name                = var.diagnostic_eventhub_namespace_name != "" ? var.diagnostic_eventhub_namespace_name : "eh-diag-${data.azurerm_resource_group.this.location}-${random_string.eventhub_suffix[0].result}"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "Standard"
  capacity            = 1

  tags = {
    environment = "development"
    managed-by  = "terraform"
    project     = "eventhub-monitoring"
    purpose     = "diagnostic-logs-destination"
  }
}

# ==============================================================================
# Log Analytics Workspace
# ==============================================================================

resource "azurerm_log_analytics_workspace" "this" {
  count               = var.enable_log_analytics ? 1 : 0
  name                = "log-eh-${data.azurerm_resource_group.this.location}"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    environment = "development"
    managed-by  = "terraform"
    project     = "eventhub-monitoring"
    purpose     = "eventhub-monitoring"
  }
}

# ==============================================================================
# Storage Account for Diagnostic Archiving
# ==============================================================================

resource "azurerm_storage_account" "diagnostic" {
  count                           = var.enable_storage_account ? 1 : 0
  name                            = var.storage_account_name != "" ? var.storage_account_name : "diageh${random_string.storage_suffix[0].result}"
  resource_group_name             = data.azurerm_resource_group.this.name
  location                        = data.azurerm_resource_group.this.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  default_to_oauth_authentication = true

  tags = {
    environment = "development"
    managed-by  = "terraform"
    project     = "eventhub-monitoring"
    purpose     = "diagnostic-archiving"
  }
}

resource "random_string" "storage_suffix" {
  count   = var.enable_storage_account ? 1 : 0
  length  = 16
  upper   = false
  special = false
}

# ==============================================================================
# Event Hub for Diagnostic Streaming
# ==============================================================================

resource "azurerm_eventhub" "diagnostic_logs" {
  count             = var.enable_eventhub_streaming ? 1 : 0
  name              = "diagnostic-logs"
  namespace_id      = azurerm_eventhub_namespace.diagnostic[0].id
  partition_count   = 2
  message_retention = 1
}

resource "azurerm_eventhub_namespace_authorization_rule" "diagnostic_logs" {
  count               = var.enable_eventhub_streaming ? 1 : 0
  name                = "diagnostic-logs-auth-rule"
  namespace_name      = azurerm_eventhub_namespace.diagnostic[0].name
  resource_group_name = data.azurerm_resource_group.this.name

  listen = true
  send   = true
  manage = false
}

# ==============================================================================
# Diagnostic Setting
# ==============================================================================

resource "azurerm_monitor_diagnostic_setting" "eventhub_monitoring" {
  name               = "diag-eh-${data.azurerm_eventhub_namespace.monitored.name}"
  target_resource_id = data.azurerm_eventhub_namespace.monitored.id
  
  # Conditional destinations
  log_analytics_workspace_id     = var.enable_log_analytics ? azurerm_log_analytics_workspace.this[0].id : null
  storage_account_id            = var.enable_storage_account ? azurerm_storage_account.diagnostic[0].id : null
  eventhub_name                 = var.enable_eventhub_streaming ? azurerm_eventhub.diagnostic_logs[0].name : null
  eventhub_authorization_rule_id = var.enable_eventhub_streaming ? azurerm_eventhub_namespace_authorization_rule.diagnostic_logs[0].id : null

  # Using AzureDiagnostics table (not Dedicated) to get ConsumerGroup and PartitionId fields
  
  enabled_log {
    category = "ApplicationMetricsLogs"
  }

  enabled_log {
    category = "OperationalLogs"
  }

  enabled_log {
    category = "RuntimeAuditLogs"
  }

  enabled_log {
    category = "DiagnosticErrorLogs"
  }

  enabled_log {
    category = "EventHubVNetConnectionEvent"
  }
}

# ==============================================================================
# Outputs
# ==============================================================================

output "resource_group_name" {
  value       = data.azurerm_resource_group.this.name
  description = "The name of the resource group"
}

output "resource_group_location" {
  value       = data.azurerm_resource_group.this.location
  description = "The location of the resource group"
}

output "monitored_eventhub_namespace_id" {
  value       = data.azurerm_eventhub_namespace.monitored.id
  description = "The ID of the monitored Event Hub namespace"
}

output "monitored_eventhub_namespace_name" {
  value       = data.azurerm_eventhub_namespace.monitored.name
  description = "The name of the monitored Event Hub namespace"
}

output "diagnostic_eventhub_namespace_id" {
  value       = var.enable_eventhub_streaming ? azurerm_eventhub_namespace.diagnostic[0].id : null
  description = "The ID of the diagnostic Event Hub namespace"
}

output "diagnostic_eventhub_namespace_name" {
  value       = var.enable_eventhub_streaming ? azurerm_eventhub_namespace.diagnostic[0].name : null
  description = "The name of the diagnostic Event Hub namespace"
}

output "log_analytics_workspace_name" {
  value       = var.enable_log_analytics ? azurerm_log_analytics_workspace.this[0].name : null
  description = "The name of the Log Analytics workspace"
}

output "log_analytics_workspace_id" {
  value       = var.enable_log_analytics ? azurerm_log_analytics_workspace.this[0].id : null
  description = "The ID of the Log Analytics workspace"
}

output "log_analytics_workspace_customer_id" {
  value       = var.enable_log_analytics ? azurerm_log_analytics_workspace.this[0].workspace_id : null
  description = "The workspace (customer) ID of the Log Analytics workspace"
}

output "storage_account_name" {
  value       = var.enable_storage_account ? azurerm_storage_account.diagnostic[0].name : null
  description = "The name of the diagnostic storage account"
}

output "storage_account_id" {
  value       = var.enable_storage_account ? azurerm_storage_account.diagnostic[0].id : null
  description = "The ID of the diagnostic storage account"
}

output "diagnostic_eventhub_name" {
  value       = var.enable_eventhub_streaming ? azurerm_eventhub.diagnostic_logs[0].name : null
  description = "The name of the diagnostic Event Hub"
}

output "diagnostic_eventhub_connection_string" {
  value       = var.enable_eventhub_streaming ? azurerm_eventhub_namespace_authorization_rule.diagnostic_logs[0].primary_connection_string : null
  description = "The primary connection string for the diagnostic Event Hub"
  sensitive   = true
}

output "diagnostic_setting_name" {
  value       = azurerm_monitor_diagnostic_setting.eventhub_monitoring.name
  description = "The name of the diagnostic setting"
}

output "diagnostic_setting_id" {
  value       = azurerm_monitor_diagnostic_setting.eventhub_monitoring.id
  description = "The ID of the diagnostic setting"
}