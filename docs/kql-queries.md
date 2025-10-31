# KQL Queries for Event Hubs Monitoring

This document contains a set of KQL queries for analyzing Event Hubs diagnostic data stored in a Log Analytics workspace.

## Consumer Lag Queries (`AzureDiagnostics` Table)

Use these queries if your diagnostic setting is configured to send data to the legacy `AzureDiagnostics` table.

```kusto
// View all ConsumerLag metrics with consumer group and partition details
AzureDiagnostics
| where Category == "ApplicationMetricsLogs" and ActivityName_s == "ConsumerLag"
| project TimeGenerated, ConsumerGroup=ChildEntityName_s, PartitionId=PartitionId_s, 
          ConsumerLag=Count_d, EventHub=EntityName_s, Namespace=NamespaceName_s
| order by TimeGenerated desc

// Average lag per consumer group over time (5-minute intervals)
AzureDiagnostics
| where Category == "ApplicationMetricsLogs" and ActivityName_s == "ConsumerLag"
| summarize AvgLag = avg(Count_d), MaxLag = max(Count_d) 
    by bin(TimeGenerated, 5m), ConsumerGroup=ChildEntityName_s, EventHub=EntityName_s
| order by TimeGenerated desc

// Latest lag per consumer group and partition
AzureDiagnostics
| where Category == "ApplicationMetricsLogs" and ActivityName_s == "ConsumerLag"
| summarize arg_max(TimeGenerated, Count_d) 
    by ConsumerGroup=ChildEntityName_s, PartitionId=PartitionId_s, EventHub=EntityName_s
| project ConsumerGroup, PartitionId, LatestLag=Count_d, LastUpdated=TimeGenerated, EventHub
| order by ConsumerGroup, PartitionId

// Render lag as a timechart
AzureDiagnostics
| where ActivityName_s == 'ConsumerLag'
| project
    Activity = ActivityName_s,
    PartitionId = PartitionId_s,
    Count = Count_d,
    Timestamp = TimeGenerated
| summarize avg(Count) by bin(Timestamp, 1m), PartitionId
| order by Timestamp desc
| render timechart
```
