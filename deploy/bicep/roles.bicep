
param EventHubNamespace string
param CheckpointAccountName string
param ManagedIdentityID string
param ManagedIdentityResourceId string

// Built-in Azure role definition IDs (stable across all Azure subscriptions)
var roleIdMapping = {
  MonitoringMetricPublisherAssignment : '3913510d-42f4-4e42-8a64-420c390055eb'  // Monitoring Metrics Publisher
  EventHubDataOwnerAssignment : 'f526a384-b230-433a-b45c-95f59c4a2dec'          // Azure Event Hubs Data Owner
  StorageBlobDataReaderAssignment : '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'     // Storage Blob Data Reader
}


// pick the existing event hub and storage account

resource eventHub 'Microsoft.EventHub/namespaces@2021-11-01' existing = {
  name: EventHubNamespace
}

resource checkpointStorage 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: CheckpointAccountName
}


resource EventHubDataOwnerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(eventHub.id, ManagedIdentityResourceId, roleIdMapping.EventHubDataOwnerAssignment)
  scope: eventHub
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIdMapping.EventHubDataOwnerAssignment)
    principalId: ManagedIdentityID
    principalType: 'ServicePrincipal'
  }
}

resource StorageBlobDataReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(checkpointStorage.id, ManagedIdentityResourceId, roleIdMapping.StorageBlobDataReaderAssignment)
  scope: checkpointStorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIdMapping.StorageBlobDataReaderAssignment)
    principalId: ManagedIdentityID
    principalType: 'ServicePrincipal'
  }
}

resource MonitoringMetricPublisherAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(eventHub.id, ManagedIdentityResourceId, roleIdMapping.MonitoringMetricPublisherAssignment)
  scope: eventHub
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIdMapping.MonitoringMetricPublisherAssignment)
    principalId: ManagedIdentityID
    principalType: 'ServicePrincipal'
  }
}

// ACR Pull role assignment - handled separately due to cross-resource-group scope limitations
// This will be assigned via Azure CLI command after deployment
