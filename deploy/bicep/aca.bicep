
@description('default to resource group location.')
param location string = resourceGroup().location



@description('Name of the Container App Environment')
param AcaEnvName string



resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview'  = {
  name: 'emitter-log-analytics-java'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}


resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2022-06-01-preview'  = {
  name: AcaEnvName  
  location: location 
    properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}



// in case using an existing log analytics workspace - this is the code to use
// resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
//   name: 'emitter-log-analytics'
//   scope: resourceGroup() 
// }

// and this is the code to use for the existing container app environment

// resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2022-06-01-preview' existing = {
//     name: name   
// }



@description('Name of the Emitter Container App')
param EmitterImage string
@description('Name of the Emitter Registry')
param registryLoginServer string



@description('Managed Identity Client Id - created in main.bicep')
param ManagedIdentityClientId string

@description('Managed Identity Client Id - created in main.bicep')
param ManagedIdentityId string


@description('Event Hub Namespace - provided in the param.json file')
param EventHubNamespace string

@description('Event Hub - provided in the param.json file')
param EventHubName string

// consider to also pass in param file (or we should take all consumer groups)
param ConsumerGroup string = '$Default'


@description('Storage Account Name - provided in the param.json file')
param CheckpointAccountName string

@description('Storage Container Name - provided in the param.json file')
param CheckpointContainerName string

@description('Custom Metric Interval - provided in the param.json file')
param CustomMetricInterval string



resource ContainerApp 'Microsoft.App/containerApps@2022-06-01-preview' = {
  name: 'eh-lag-emitter-java'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${ManagedIdentityId}':{}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    
    configuration: {
      registries: [
        {
          server: registryLoginServer
          identity: ManagedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'emitter' 
          image: '${registryLoginServer}/${EmitterImage}' 
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          } 
          env: [
            {
              name: 'TenantId'
              value: subscription().tenantId
            }
            {
              name: 'SubscriptionId'
              value: subscription().subscriptionId
            }            
            {
              name: 'ResourceGroup'
              value: resourceGroup().name
            }            
            {
              name: 'Region'
              value: location
            }            
            {
              name: 'EventHubNamespace'
              value: EventHubNamespace
            }            
            {
              name: 'EventHubName'
              value: EventHubName
            }            
            {
              name: 'ConsumerGroup'
              value: ConsumerGroup
            }            
            {
              name: 'CheckpointAccountName'
              value: CheckpointAccountName
            }            
            {
              name: 'CheckpointContainerName'
              value: CheckpointContainerName
            }            
            {
              name: 'CustomMetricInterval'
              value: CustomMetricInterval
            } 
            {
              name: 'ManagedIdentityClientId'
              value: ManagedIdentityClientId
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: 'InstrumentationKey=b5965a4f-ece5-44da-a1db-edb49acec627;IngestionEndpoint=https://uksouth-1.in.applicationinsights.azure.com/;LiveEndpoint=https://uksouth.livediagnostics.monitor.azure.com/;ApplicationId=6f9453e2-b2bf-4a32-85b4-9ff5d6014b1f'
            }

          ]        
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

