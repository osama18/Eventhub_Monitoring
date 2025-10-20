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
  description = "Name of the Event Hub namespace"
}

# ==============================================================================
# Provider
# ==============================================================================

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_eventhub_namespace" "this" {
  name                = var.eventhub_namespace_name
  resource_group_name = data.azurerm_resource_group.this.name
}

# ==============================================================================
# Log Analytics Workspace
# ==============================================================================

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-eh-consumerlag-${data.azurerm_resource_group.this.location}"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    environment = "development"
    managed-by  = "terraform"
    project     = "eventhub-monitoring"
    purpose     = "eventhub-consumerlag-monitoring"
  }
}

# ==============================================================================
# Diagnostic Setting
# ==============================================================================

resource "azurerm_monitor_diagnostic_setting" "eventhub_consumerlag" {
  name                           = "diag-consumerlag-${data.azurerm_eventhub_namespace.this.name}"
  target_resource_id             = data.azurerm_eventhub_namespace.this.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
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

output "eventhub_namespace_id" {
  value       = data.azurerm_eventhub_namespace.this.id
  description = "The ID of the Event Hub namespace"
}

output "log_analytics_workspace_name" {
  value       = azurerm_log_analytics_workspace.this.name
  description = "The name of the Log Analytics workspace"
}

output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.this.id
  description = "The ID of the Log Analytics workspace"
}

output "log_analytics_workspace_customer_id" {
  value       = azurerm_log_analytics_workspace.this.workspace_id
  description = "The workspace (customer) ID of the Log Analytics workspace"
}

output "diagnostic_setting_name" {
  value       = azurerm_monitor_diagnostic_setting.eventhub_consumerlag.name
  description = "The name of the diagnostic setting"
}

output "diagnostic_setting_id" {
  value       = azurerm_monitor_diagnostic_setting.eventhub_consumerlag.id
  description = "The ID of the diagnostic setting"
}