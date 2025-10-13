terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
  
  backend "azurerm" {
    resource_group_name  = "cdpp-infra"
    storage_account_name = "cdppterraformstate"
    container_name       = "tfstate"
    key                  = "fabric/terraform.tfstate"
  }
}

provider "azurerm" {
  subscription_id = "fcde6cf3-f69d-4b81-9ae3-7c1187597de0"
  features {}
}

# Data source for existing resource group
data "azurerm_resource_group" "cdpp_infra" {
  name = "cdpp-infra"
}

# Data source for existing managed identity
data "azurerm_user_assigned_identity" "cubejs_identity" {
  name                = "cubejs-identity"
  resource_group_name = data.azurerm_resource_group.cdpp_infra.name
}

# Fabric capacity resource
resource "azurerm_fabric_capacity" "fabric_capacity" {
  name                = "cdppfabricpoc"
  resource_group_name = data.azurerm_resource_group.cdpp_infra.name
  location           = data.azurerm_resource_group.cdpp_infra.location
  
  sku {
    name = "F2"
    tier = "Fabric"
  }
  
  administration_members = [
    "ada@sitecoreplatform.io",
    data.azurerm_user_assigned_identity.cubejs_identity.principal_id
  ]
  
  tags = {
    Environment = "production"
    Project     = "CDPP"
  }
}