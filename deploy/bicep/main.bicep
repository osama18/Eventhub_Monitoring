
@description('The location of the resource group and the location in which all resurces would be created')
param location string = resourceGroup().location

@description('Storage Account Name - provided in the param.json file')
param CheckpointAccountName string

@description('Storage Container Name - provided in the param.json file')
param CheckpointContainerName string

@description('Custom Metric Interval - provided in the param.json file')
param CustomMetricInterval string

@description('Event Hub Namespace - provided in the param.json file')
param EventHubNamespace string

@description('Event Hub - provided in the param.json file')
param EventHubName string

@description('managed identity name from param.json file')
param managedIdentityName string 

@description('container app environment name from param.json file')
param AcaEnvName string

@description('Azure Container Registry name')
param AcrName string

// create a managed identity
resource mngIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: managedIdentityName  
  location: location
}

// reference the existing ACR (assumed to be in the same resource group)
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  name: AcrName
}

// assign ACR Pull role to the managed identity
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('AcrPull', mngIdentity.id, containerRegistry.id)
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull role
    principalId: mngIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// when using an existing managed identity, using the 'existing' keyword will not create a new one rather it will use the existing one
// resource mngIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
//   name: managedIdentityName
//   scope: resourceGroup()   
// }

// assign role to the managed identity using a module
module roles 'roles.bicep' = {
  name: 'roles'
  params: {    
    ManagedIdentityID: mngIdentity.properties.principalId
    EventHubNamespace: EventHubNamespace
    CheckpointAccountName: CheckpointAccountName
  }
}


// create aca resource (depends on ACR role assignment)
module ACA 'aca.bicep' = {
  name: 'aca-emitter'
  dependsOn: [
    acrPullRoleAssignment  // Ensure ACR permissions are set before creating Container App
  ]
  params: {
    location: location
    ManagedIdentityId: mngIdentity.id
    ManagedIdentityClientId: mngIdentity.properties.clientId
    EventHubNamespace: EventHubNamespace
    CheckpointAccountName: CheckpointAccountName
    AcaEnvName: AcaEnvName
    EventHubName: EventHubName
    CheckpointContainerName: CheckpointContainerName
    CustomMetricInterval: CustomMetricInterval
    EmitterImage: 'eventhub-custom-metrics-emitter-java:latest'
    registryLoginServer: '${AcrName}.azurecr.io'
  }
}

// Output the managed identity principal ID for role assignments
output managedIdentityPrincipalId string = mngIdentity.properties.principalId