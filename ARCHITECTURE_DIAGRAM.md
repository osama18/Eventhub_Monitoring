# EventHub Custom Metrics Emitter - Infrastructure Diagram

## Mermaid Flow Diagram

Copy and paste this into any Mermaid-compatible viewer (GitHub, Mermaid Live Editor, etc.):

```mermaid
graph TB
    subgraph "Input Parameters"
        P1[location]
        P2[managedIdentityName]
        P3[AcaEnvName]
        P4[AcrName]
        P5[EventHubNamespace]
        P6[EventHubName]
        P7[CheckpointAccountName]
        P8[CheckpointContainerName]
        P9[CustomMetricInterval]
    end

    subgraph "Existing Resources (Referenced)"
        ACR[Azure Container Registry<br/>acrlag6]
        EH[Event Hub Namespace<br/>eh-lag-metric]
        SA[Storage Account<br/>ehlagmetricsa]
    end

    subgraph "main.bicep - Created Resources"
        MI[Managed Identity<br/>eventhub-metrics-identity-java<br/>Type: UserAssigned]
        
        RA1[Role Assignment<br/>ACR Pull Role<br/>Scope: Container Registry]
    end

    subgraph "roles.bicep Module - Role Assignments"
        RA2[Role Assignment<br/>Event Hubs Data Owner<br/>Scope: Event Hub]
        RA3[Role Assignment<br/>Storage Blob Data Reader<br/>Scope: Storage Account]
        RA4[Role Assignment<br/>Monitoring Metrics Publisher<br/>Scope: Event Hub]
    end

    subgraph "aca.bicep Module - Container Infrastructure"
        LA[Log Analytics Workspace<br/>emitter-log-analytics-java<br/>SKU: PerGB2018]
        
        ENV[Container App Environment<br/>my-container-app-env-java<br/>API: 2023-05-01]
        
        CA[Container App<br/>eh-lag-emitter-java<br/>Image: eventhub-custom-metrics-emitter-java:latest<br/>CPU: 0.25, Memory: 0.5Gi]
    end

    subgraph "Runtime Application Flow"
        APP[Java Spring Boot App<br/>Metrics Worker Service<br/>Interval: 10 seconds]
        
        EHREAD[Read EventHub<br/>Partition Lag]
        SAREAD[Read Blob Storage<br/>Checkpoint Data]
        MONITOR[Publish Custom Metrics<br/>Azure Monitor API]
    end

    %% Dependencies - main.bicep
    P2 --> MI
    P4 --> ACR
    MI --> RA1
    ACR --> RA1
    
    %% Dependencies - roles.bicep module
    MI --> RA2
    MI --> RA3
    MI --> RA4
    EH --> RA2
    EH --> RA4
    SA --> RA3
    P5 --> RA2
    P5 --> RA4
    P7 --> RA3

    %% Dependencies - aca.bicep module
    P1 --> LA
    LA --> ENV
    ENV --> CA
    MI --> CA
    ACR --> CA
    RA1 --> CA
    
    %% Runtime flow
    CA --> APP
    APP --> EHREAD
    APP --> SAREAD
    APP --> MONITOR
    
    RA2 --> EHREAD
    RA3 --> SAREAD
    RA4 --> MONITOR
    
    EHREAD --> EH
    SAREAD --> SA
    
    %% Styling
    classDef created fill:#90EE90,stroke:#006400,stroke-width:2px,color:#000
    classDef existing fill:#87CEEB,stroke:#00008B,stroke-width:2px,color:#000
    classDef role fill:#FFD700,stroke:#FF8C00,stroke-width:2px,color:#000
    classDef runtime fill:#FFB6C1,stroke:#C71585,stroke-width:2px,color:#000
    classDef param fill:#E6E6FA,stroke:#4B0082,stroke-width:1px,color:#000
    
    class MI,LA,ENV,CA created
    class ACR,EH,SA existing
    class RA1,RA2,RA3,RA4 role
    class APP,EHREAD,SAREAD,MONITOR runtime
    class P1,P2,P3,P4,P5,P6,P7,P8,P9 param
```

## Legend

- 🟢 **Green** - Resources created by deployment
- 🔵 **Blue** - Existing resources (must exist before deployment)
- 🟡 **Yellow** - Role assignments (RBAC permissions)
- 🌸 **Pink** - Runtime application flow
- 🟣 **Purple** - Input parameters

## Deployment Flow

1. **Create Managed Identity** → Used for all authentication
2. **Assign ACR Pull Role** → Allows pulling container images
3. **Create roles.bicep module** → Assigns EventHub, Storage, and Monitoring permissions
4. **Create aca.bicep module** → Sets up Log Analytics, Container App Environment, and Container App
5. **Runtime** → Application reads EventHub lag, reads checkpoints from Storage, publishes to Azure Monitor

## Key Dependencies

- Container App **depends on** ACR Pull role assignment (can't pull image without it)
- Container App **uses** Managed Identity for authentication
- Application **requires** 3 role assignments to function:
  - Event Hubs Data Owner (read partition info)
  - Storage Blob Data Reader (read checkpoints)
  - Monitoring Metrics Publisher (publish custom metrics)

## Resource Naming

| Resource Type | Name | Defined In |
|--------------|------|------------|
| Managed Identity | `eventhub-metrics-identity-java` | param.json |
| Container App | `eh-lag-emitter-java` | aca.bicep (hardcoded) |
| Container App Environment | `my-container-app-env-java` | param.json |
| Log Analytics Workspace | `emitter-log-analytics-java` | aca.bicep (hardcoded) |
| ACR | `acrlag6` | param.json |
| Event Hub Namespace | `eh-lag-metric` | param.json (existing) |
| Storage Account | `ehlagmetricsa` | param.json (existing) |

---

## Deployment Flow Sequence Diagram

This diagram shows the **order of deployment steps** and dependencies:

```mermaid
sequenceDiagram
    autonumber
    participant User
    participant Bicep as main.bicep
    participant Azure
    participant Roles as roles.bicep
    participant ACA as aca.bicep
    participant App as Container App
    
    Note over User,App: Deployment Phase
    
    User->>Bicep: make all (or make az-deploy)
    activate Bicep
    
    Bicep->>Azure: Create Managed Identity
    Azure-->>Bicep: ✓ Identity Created (principalId)
    
    Bicep->>Azure: Reference existing ACR
    Azure-->>Bicep: ✓ ACR Found
    
    Bicep->>Azure: Assign ACR Pull Role to Identity
    Note right of Azure: Scope: Container Registry
    Azure-->>Bicep: ✓ Role Assignment Created
    
    Bicep->>Roles: Call roles.bicep module
    activate Roles
    
    Roles->>Azure: Reference existing EventHub
    Azure-->>Roles: ✓ EventHub Found
    
    Roles->>Azure: Reference existing Storage Account
    Azure-->>Roles: ✓ Storage Account Found
    
    Roles->>Azure: Assign Event Hubs Data Owner
    Note right of Azure: Scope: EventHub Namespace
    Azure-->>Roles: ✓ Role Assignment Created
    
    Roles->>Azure: Assign Storage Blob Data Reader
    Note right of Azure: Scope: Storage Account
    Azure-->>Roles: ✓ Role Assignment Created
    
    Roles->>Azure: Assign Monitoring Metrics Publisher
    Note right of Azure: Scope: EventHub Namespace
    Azure-->>Roles: ✓ Role Assignment Created
    
    Roles-->>Bicep: ✓ All roles assigned
    deactivate Roles
    
    Bicep->>ACA: Call aca.bicep module
    activate ACA
    
    ACA->>Azure: Create Log Analytics Workspace
    Azure-->>ACA: ✓ Workspace Created (customerId)
    
    ACA->>Azure: Create Container App Environment
    Note right of Azure: Links to Log Analytics
    Azure-->>ACA: ✓ Environment Created
    
    ACA->>Azure: Create Container App
    Note right of Azure: Uses Managed Identity<br/>Depends on ACR role<br/>Links to Environment
    Azure-->>ACA: ✓ Container App Created
    
    ACA-->>Bicep: ✓ Infrastructure Ready
    deactivate ACA
    
    Bicep-->>User: ✓ Deployment Complete
    deactivate Bicep
    
    Note over User,App: Runtime Phase (Every 10 seconds)
    
    Azure->>App: Pull container image from ACR
    Note right of App: Uses ACR Pull role
    
    App->>Azure: Start container
    activate App
    
    App->>Azure: Authenticate with Managed Identity
    Note right of Azure: Gets access token
    Azure-->>App: ✓ Token (EventHub scope)
    
    App->>Azure: Read EventHub partition properties
    Note right of Azure: Uses Event Hubs Data Owner role
    Azure-->>App: Partition 0, 1 info
    
    App->>Azure: Get token (Storage scope)
    Azure-->>App: ✓ Token (Storage scope)
    
    App->>Azure: Read checkpoint blobs
    Note right of Azure: Uses Storage Blob Data Reader role
    Azure-->>App: Checkpoint data
    
    App->>App: Calculate lag metrics
    
    App->>Azure: Get token (Monitor scope)
    Azure-->>App: ✓ Token (Monitor scope)
    
    App->>Azure: Publish custom metrics via HTTP
    Note right of Azure: Uses Monitoring Metrics Publisher role
    Azure-->>App: ✓ 200 OK
    
    App->>Azure: Send logs to Log Analytics
    Azure-->>App: ✓ Logs ingested
    
    deactivate App
    
    Note over App: Wait 10 seconds, repeat...
```

## Deployment Steps Summary

### Phase 1: Identity and Permissions (main.bicep)
1. **Create Managed Identity** - The security principal for all operations
2. **Assign ACR Pull Role** - Enables pulling container images

### Phase 2: Application Permissions (roles.bicep)
3. **Assign Event Hubs Data Owner** - Read partition lag information
4. **Assign Storage Blob Data Reader** - Read checkpoint data
5. **Assign Monitoring Metrics Publisher** - Publish custom metrics

### Phase 3: Container Infrastructure (aca.bicep)
6. **Create Log Analytics Workspace** - Centralized logging
7. **Create Container App Environment** - Hosting environment
8. **Create Container App** - Deploy the application container

### Phase 4: Runtime Execution (Every 10 seconds)
9. **Authenticate** - Get access tokens via Managed Identity
10. **Read EventHub** - Get partition properties
11. **Read Storage** - Get checkpoint data
12. **Calculate** - Compute lag metrics
13. **Publish** - Send metrics to Azure Monitor
14. **Log** - Send application logs to Log Analytics

## Critical Dependencies

The sequence diagram shows these **must-happen-before** relationships:

- ✅ **Managed Identity must exist** before any role assignments
- ✅ **ACR Pull role must be assigned** before Container App creation
- ✅ **Log Analytics must exist** before Container App Environment
- ✅ **Container App Environment must exist** before Container App
- ✅ **All role assignments must complete** before application can function properly

---

## How to View These Diagrams

1. **In VS Code**: Press `Ctrl+Shift+V` (or `Cmd+Shift+V`) to open Markdown preview
2. **Online**: Copy the code and paste into https://mermaid.live/
3. **GitHub**: Push to GitHub and view the README - Mermaid renders automatically!

