# Azure Event Hubs Observability Design (Template)

## Table of Contents
1. [Context](#1-context)
2. [Key Risks & Mitigations](#2-key-risks--mitigations)
3. [Service Level Objectives (SLOs)](#3-service-level-objectives-slos)
4. [Service Level Indicators (SLIs)](#4-service-level-indicators-slis)
5. [Alerting Strategy](#5-alerting-strategy)
6. [Core Metrics](#6-core-metrics)
7. [Key Design Formulas](#7-key-design-formulas)
8. [Implementation Notes](#8-implementation-notes)
9. [Cost Guardrails & Optimization](#9-cost-guardrails--optimization)
10. [Variables](#10-variables)

## 1. Context

This design is for a system on the Azure Event Hubs Premium tier. It assumes producers/consumers use SDKs, and each consumer instance is mapped to a single partition, using Azure Blob Storage for checkpointing.

A key assumption of this design is the absence of "hot partitions." This means we presume that the data is distributed evenly across all partitions, without any single partition receiving a disproportionately large amount of traffic. This is typically achieved by using a partition key that ensures a balanced load. An unbalanced load, or "partition skew," can lead to localized performance bottlenecks that may not be visible when looking at the overall system metrics.

## 2. Key Risks & Mitigations

This section is structured around the primary business risks. Each risk section outlines its causes and maps the alerts that act as warning signs or indicators of an actual occurrence.

---

### **Risk: Data Loss (Sev1)**

- **Business Impact:** The irreversible loss of data, representing a critical failure of the system's primary function. This is the most severe failure mode.

- **Primary Causes:**
    - **Ingestion Unavailability:** The Event Hubs service is unable to accept new events from producers.
    - **[Unchecked Consumer Lag Growth](#risk-deep-dive-lag):** The backlog grows so large that the service becomes saturated, causing producers to be throttled for an extended period.

- **Detection & Alerting (for Ingestion Unavailability):**

| Signal Classification | Alert Name & Link | Why it Matters |
| :--- | :--- | :--- |
| **Critical Incident** | [Ingestion Halted by Throttling](#alert-ingestion-halted) | **The system has failed.** No data is being ingested due to throttling. This is an active data loss scenario. |
| **Critical Incident** | [Availability Burn Rate](#alert-availability-burn) | **Fast Burn:** The error budget is burning at a critical rate, indicating a major outage. <br> **Slow Burn:** A low-grade error has been sustained for hours, indicating sustained degradation. |
| **Urgent Warning** | [Connection Headroom](#alert-connection-headroom) | The namespace is nearing its connection limit. New producers may soon be rejected, halting ingestion. |
| **Degradation Warning** | [Producer Throttling](#alert-producer-throttling) | The system is under pressure. Producers are being slowed down, a leading indicator of potential saturation. |
| **Degradation Warning** | [Publish Success SLO Breach](#alert-publish-success-breach) | A sustained failure of end-to-end publish operations can lead to data loss if retries are exhausted. |

---

### **Risk: Data Staleness (Sev2)**

- **Business Impact:** Data is not lost, but it is delayed beyond the SLO, impacting the timeliness of downstream business processes.

- **Primary Causes:**
    - **High Publish Latency:** It takes too long for producers to send data into the system.
    - **[Unchecked Consumer Lag Growth](#risk-deep-dive-lag):** Consumers are unable to keep up with the rate of incoming data.

- **Detection & Alerting:**

| Signal Classification | Alert Name & Link | Why it Matters |
| :--- | :--- | :--- |
| **Critical Incident** | [Publish Latency SLO Breach](#alert-latency-breach) | **The system is failing now.** The time to publish messages is actively breaching the SLO, causing immediate data staleness. |
| **Degradation Warning** | [Publish Success SLO Breach](#alert-publish-success-breach) | Even if publishes eventually succeed, repeated failures and retries contribute directly to data staleness. |

---

### <span id="risk-deep-dive-lag"></span>**Deep Dive: Unchecked Consumer Lag Growth**

This is a special case as it is a primary cause for *both* Data Staleness and Data Loss.

- **Business Impact:** Causes **Data Staleness (Sev2)** in the short term and can escalate to **Data Loss (Sev1)** if the lag exceeds the data retention period.

- **Primary Causes:**
    - **Consumer(s) Down:** The consumer application has crashed, is unresponsive, or cannot acquire a partition lease.
    - **Consumer(s) Slow:** The application is running but cannot process messages fast enough due to inefficient code, resource constraints (CPU/Memory), or slow downstream dependencies.
    - **Sustained Processing Errors:** An unprocessable message (e.g., due to a deserialization failure) or an external dependency failure is causing events to be constantly retried and sent to a custom-managed dead-letter queue instead of being processed (as Event Hubs does not have a built-in DLQ).

- **Detection & Alerting:**

| Signal Classification | Alert Name & Link | Why it Matters |
| :--- | :--- | :--- |
| **Critical Incident** | [Consumer Heartbeat Missing](#alert-heartbeat-missing) | **The consumer is down.** This is a critical alert indicating a complete failure of a consumer instance. |
| **Critical Incident** | [Backlog Freshness SLO Breach](#alert-backlog-breach) | **The backlog is too large.** This is the ultimate lagging indicator that consumer lag has breached the business-defined threshold. |
| **Degradation Warning** | [Consumer Processing SLO Breach](#alert-consumer-processing-breach) | This is a direct measurement of "Consumer(s) Slow." It's a leading indicator that lag will begin to grow. |
| **Degradation Warning** | [Predictive Lag](#alert-predictive-lag) | A proactive calculation that warns that consumers are not provisioned with enough capacity to keep up. |

## 3. Service Level Objectives (SLOs)

SLOs are the internal targets set for our SLIs over a specific time window. They represent our commitment to service performance.

> _**Note**: The percentage-based objectives in this section (e.g., 99.9%) are common industry starting points. You should adjust these targets based on your specific business requirements, user expectations, and cost considerations._

- <span id="slo-availability"></span>**Ingestion Availability**: Over a trailing 30-day period, ingestion availability will be **≥ 99.9%** across rolling 5-minute windows.
  - **Governing SLI**: [Ingestion Availability SLI](#sli-availability)
  > _This target aligns with the official Event Hubs Premium SLA and is the basis for [burn-rate](#note-burn-rate)._

- <span id="slo-backlog-freshness"></span>**Backlog Freshness**: Over a trailing 30-day period, at least **99%** of rolling 5-minute windows must satisfy p99(consumerLagInSeconds) ≤ [consumer_lag_seconds_threshold](#var-consumer-lag)
  - **Governing SLI**: [Backlog Freshness SLI](#sli-backlog-freshness)
  > _This SLO defines the business requirement for data freshness. Compliance is measured using a derived message count threshold (`Lₘ`) calculated from this time-based goal. See [Backlog Thresholds and Clearance](#backlog-thresholds) for the formula._

- <span id="slo-publish-success"></span>**Publish Success**: Over a trailing 30-day period, at least **99.9%** of rolling 5-minute windows record publishes succeeding within `Wᵣ` seconds (retries included), where `Wᵣ` is the publish success retry window.
  - **Governing SLI**: [Publish Success SLI](#sli-publish-success)
  > _A failure to meet this SLO often points to the [sustained throttling risk](#risk-sustained-throttling)._

- <span id="slo-publish-latency"></span>**Publish Latency (Tail)**: Over a trailing 30-day period, at least **99.9%** of rolling 5-minute windows must maintain a p99 enqueue-to-ACK latency of **≤ [publish_latency_p99_ms](#var-publish-latency) ms**.
  - **Governing SLI**: [Publish Latency (Tail) SLI](#sli-publish-latency)
  > _This SLO ensures that even the slowest 1% of publish operations complete within acceptable timeframes, preventing user-facing delays._

- <span id="slo-consumer-efficiency"></span>**Consumer Processing Efficiency**: Over a trailing 30-day period, at least **99%** of rolling 5-minute windows must hold p95 consumer processing latency at **≤ [consumer_processing_p95_ms](#var-consumer-processing) ms**.
  - **Governing SLI**: [Consumer Processing Efficiency SLI](#sli-consumer-efficiency)
  > _Excursions indicate throughput gaps that threaten data timeliness and can be escalated to full evenhub saturation._

- <span id="slo-connection-headroom"></span>**Connection Headroom**: Over a trailing 30-day period, at least **99%** of rolling 15-minute windows must keep active connections **≤ [connection_headroom_percent](#var-connection-headroom)%** of the Premium limit per PU.
  - **Governing SLI**: [Connection Headroom SLI](#sli-connection-headroom)
  > _This SLO helps prevent client connection rejections._

## 4. Service Level Indicators (SLIs)

SLIs are user-centric indicators derived from the core metrics to measure service performance from the user's perspective.

- <span id="sli-availability"></span>**Ingestion Availability**: Ratio of successful requests to total requests processed by the Event Hubs service. This SLI directly reflects the service's reliability for producers.
  - **Formula**: `SuccessfulRequests ÷ (SuccessfulRequests + ServerErrors)`
  - **Source Metrics**: [`SuccessfulRequests`](#metric-successful-requests), [`ServerErrors`](#metric-server-errors) (from Azure Monitor)
  > _**Note**: 4xx user errors and throttled requests are excluded, as they are handled by the Publish Success SLI._

- <span id="sli-backlog-freshness"></span>**Backlog Freshness (Consumer Lag)**: Ratio of 5-minute windows where consumer lag remains within acceptable thresholds to total windows measured.
  - **Formula**: `Windows where p99(ConsumerLag) ≤ Lₘ ÷ Total Windows`, where `Lₘ` is the message count threshold derived from the time-based SLO.
  - **Source Metrics**: [`ConsumerLag`](#metric-consumer-lag) (from `AZMSApplicationMetricLogs`)
  > _**Note** `consumerLagInSeconds` is the conceptual goal this SLI tracks. This SLI is only valid if the corresponding [Consumer Heartbeat](#metric-consumer-heartbeat) is being emitted. A missing heartbeat indicates a consumer failure and a potential data freshness issue that this SLI cannot detect._

- <span id="sli-publish-success"></span>**Publish Success**: Ratio of publish attempts successfully acknowledged within the retry window to total publish attempts.
  - **Formula**: `SuccessfulRequests ÷ (SuccessfulRequests + ThrottledRequests + ServerErrors)`
  - **Source Metrics**: [`SuccessfulRequests`](#metric-successful-requests), [`ThrottledRequests`](#metric-throttled), [`ServerErrors`](#metric-server-errors), and producer-side retry logs

- <span id="sli-publish-latency"></span>**Publish Latency (Tail)**: Ratio of 5-minute windows where p99 publish latency remains within acceptable thresholds to total windows measured.
  - **Formula**: `Windows where p99(publish_latency_ms) ≤ threshold ÷ Total Windows`
  - **Source Metrics**: [`publish_latency_ms`](#metric-publish-latency) (custom metric)

- <span id="sli-consumer-efficiency"></span>**Consumer Processing Efficiency**: Ratio of 5-minute windows where p95 consumer processing time remains within acceptable thresholds to total windows measured.
  - **Formula**: `Windows where p95(consumer_processing_time_ms) ≤ threshold ÷ Total Windows`
  - **Source Metrics**: [`consumer_processing_time_ms`](#metric-consumer-processing) (custom metric)

- <span id="sli-connection-headroom"></span>**Connection Headroom**: Ratio of available connections to total connection capacity for the Premium tier.
  - **Source Metrics**: [`ActiveConnections`](#metric-active-connections) (from Azure Monitor)

## 5. Alerting Strategy

Alerts are triggered when SLOs are at risk of being breached or when a risk condition is detected. The `Severity` column in the tables below defines the expected response:
- **Page**: An urgent, high-priority alert that requires immediate attention. This is reserved for critical issues actively impacting users.
- **Ticket**: A medium-priority alert that creates a ticket in a work-tracking system. It requires investigation but not immediate, out-of-hours intervention.
- **Dashboard**: A low-priority signal that is visualized on a monitoring dashboard. It does not trigger a notification but provides context for diagnostics.

> _**Note on Alert Windows**: The `Window` column in the tables below specifies the total duration a condition must be met before an alert is fired. For example, a 10-minute window might be implemented as a check for a condition being true in two consecutive 5-minute evaluation periods._

**SLO-Based Alerts**

These alerts fire when an SLO is actively being violated or is predicted to be violated soon, indicating direct user impact.

| Alert | Governing SLO | Threshold & Window | Severity | Action / Playbook |
| --- | --- | --- | --- | --- |
| <span id="alert-availability-burn"></span>Availability Burn Rate | [Ingestion Availability](#slo-availability) | **Fast Burn:** [Burn rate](#note-burn-rate) ≥ 57.6 over 15 min <br> **Slow Burn:** [Burn rate](#note-burn-rate) ≥ 6 over 6 hours | High (Page) | **Fast Burn indicates a critical outage.** The service is failing at a rate that will consume 2% of the monthly error budget in just 15 minutes. <br> **Slow Burn indicates sustained degradation.** The service has been failing at a low but persistent rate for 6 hours, consuming 5% of the monthly error budget. |
| <span id="alert-backlog-breach"></span>Backlog Freshness SLO Breach | [Backlog Freshness](#slo-backlog-freshness) | `p99(ConsumerLag)` > [`Lₘ`](#backlog-thresholds) | 10 min | High (Page) | The message backlog has exceeded the calculated threshold `Lₘ`, which indicates a likely violation of the time-based freshness SLO. See [Backlog Thresholds](#backlog-thresholds) for calculation details. Increase consumer concurrency or optimize downstream dependencies. |
| <span id="alert-latency-breach"></span>Publish Latency SLO Breach | [Publish Latency (Tail)](#slo-publish-latency) | p99 > [publish_latency_p99_ms](#var-publish-latency) | 10 min | High (Page) | Investigate network path, throttling, and retry configuration. |
| <span id="alert-publish-success-breach"></span>Publish Success SLO Breach | [Publish Success](#slo-publish-success) | < 99.9% success | 15 min | Medium (Ticket) | **Catch-all for end-to-end publish failures.** Investigate client-side network issues, low-grade throttling, or other errors not caught by higher-priority alerts. |
| <span id="alert-consumer-processing-breach"></span>Consumer Processing SLO Breach | [Consumer Processing Efficiency](#slo-consumer-efficiency) | p99 > [consumer_processing_p95_ms](#var-consumer-processing) | 15 min | Medium (Ticket) | **Early warning for growing lag.** Investigate consumer application performance. Check for slow downstream dependencies, inefficient code, or resource contention (CPU/memory). |
| <span id="alert-connection-headroom"></span>Connection Headroom SLO Breach | [Connection Headroom](#slo-connection-headroom) | ≥ [connection_headroom_percent](#var-connection-headroom)% of limit | 15 min | High (Page) | Audit connection leaks, scale PUs, or rebalance clients. |

**Risk-Based Alerts (Proactive Warnings)**

These alerts fire on metrics that indicate a potential future risk to an SLO, allowing for proactive intervention.

| Alert | Triggering Metric | Threshold | Window | Severity | Action / Playbook |
| --- | --- | --- | --- | --- | --- |
| <span id="alert-ingestion-halted"></span>Ingestion Halted by Throttling | [`SuccessfulRequests`](#metric-successful-requests) & [`ThrottledRequests`](#metric-throttled) | `sum(SuccessfulRequests) == 0` AND `sum(ThrottledRequests) > 0` | 5 min | High (Page) | Immediately scale PUs/partitions; investigate producer configuration. |
| <span id="alert-heartbeat-missing"></span>Consumer Heartbeat Missing | [`consumer_heartbeat`](#metric-consumer-heartbeat) | No signal for `> (2 * [heartbeat_cadence_seconds](#var-heartbeat-cadence))`s | 5 min | High (Page) | Restore heartbeat pipeline; deploy custom lag metric if recurring. |
| <span id="alert-producer-throttling"></span><span id="risk-sustained-throttling"></span>Producer Throttling | [`ThrottledRequests`](#metric-throttled) | > 1/s | 5 min | Medium (Ticket) | Scale PUs/partitions; adjust producer backoff; pre-warm namespaces. |
| <span id="alert-predictive-lag"></span>Predictive Lag | [`Hₚ`](#formula-headroom) | < ([`cₚ`](#consumer-capacity) × 0.5) | 15 min | Low (Dashboard) | **Early warning for growing lag.** Consumer headroom is below 50% of capacity ([`cₚ`](#consumer-capacity)). Proactively scale up consumers or PUs before the headroom becomes negative and lag begins to grow. |
| <span id="alert-lag-diagnostics"></span>Consumer Lag Diagnostics | [`ConsumerLag`](#metric-consumer-lag) | p99 > small thresholds | 10 min | Low (Dashboard) | Visual indicator for dashboard; no action required unless other alerts fire. |

**Dashboards**

- **SLO Overview**: Availability burn rate, publish latency, and backlog freshness (p99).
- **Throughput Analysis**: `IncomingMessages`/`OutgoingMessages`, `IncomingBytes`/`OutgoingBytes`, and average event size. This dashboard is used to visualize the backlog trend by comparing ingress and egress rates.
  > _Note: This provides a coarse, namespace-level trend and can be misleading. `OutgoingMessages` aggregates reads from all consumer groups and can be inflated by consumer-side retries. For accurate backlog tracking for a specific application, rely on the `ConsumerLag` metric for its consumer group._
- **Lag Analytics**: p50/p90/p99 lag, consumer heartbeat gaps and consumer efficiency.
- **Risk Indicators**: Partition headroom ([`Hₚ`](#metric-headroom)), and connection saturation.
- **Operational Triage**: Error breakdown by type, `ThrottledRequests`, and `consumer_processing_time_ms`.

**Metric and Documentation References**:
- [Event Hubs metrics in Azure Monitor](https://learn.microsoft.com/azure/event-hubs/event-hubs-metrics-azure-monitor)
- [Azure Monitor diagnostic settings](https://learn.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings)
- [Application metrics logs reference](https://learn.microsoft.com/azure/azure-monitor/reference/tables/azmsapplicationmetriclogs)
- [Event Hubs quotas and limits](https://learn.microsoft.com/azure/event-hubs/event-hubs-quotas)
- [Event Hubs retry guidelines](https://learn.microsoft.com/azure/event-hubs/event-hubs-retry-policy)

## 6. Core Metrics

This section details the raw, quantifiable measurements collected from the system, grouped into categories. These form the foundation for the SLIs, SLOs, and alerts that follow.

**Primary Azure Monitor Metrics**

> _**Note**: These metrics are collected by Azure automatically and require no additional setup. You can view, chart, and create alerts on them directly in the Azure Portal by navigating to your Event Hubs Namespace and selecting the **Metrics** blade from the "Monitoring" section._

- <span id="metric-throughput"></span>**Throughput Metrics**: `IncomingMessages`, `OutgoingMessages`, `IncomingBytes`, and `OutgoingBytes` are used for baseline load analysis, anomaly detection, and capacity planning.
- <span id="metric-throttled"></span>**ThrottledRequests**: The count of publish requests throttled by the service. This metric is a direct indicator of capacity pressure or misconfigured producer retry policies.
- <span id="metric-active-connections"></span>**ActiveConnections**: The number of active connections on the namespace, used to monitor against the per-PU limit and prevent connection rejections.
- <span id="metric-successful-requests"></span>**SuccessfulRequests**: The count of successful requests, used as a component for calculating the availability SLI.
- <span id="metric-server-errors"></span>**ServerErrors**: The count of server-side errors, used as a component for calculating the availability SLI.

**Custom Application Metrics**

These metrics must be instrumented and emitted directly from the client application code.

- <span id="metric-consumer-processing"></span>**Consumer Processing Time**: `consumer_processing_time_ms` is a custom histogram metric measuring the latency from when an event is received by a consumer to when its processing is complete. It is essential for diagnosing consumer performance issues.
- <span id="metric-publish-latency"></span>**Publish Latency**: `publish_latency_ms` is a custom metric measuring the end-to-end latency from a producer's perspective, from the initial send call to receiving an acknowledgment from the Event Hubs service.
- <span id="metric-consumer-heartbeat"></span>**Consumer Heartbeat**: `consumer_heartbeat` is a periodic signal (e.g., a counter incremented every [heartbeat_cadence_seconds](#var-heartbeat-cadence) seconds) emitted by each consumer instance. The absence of this metric for a specific partition indicates that the consumer may be down or stalled, rendering the `ConsumerLag` metric unreliable for that partition.

**Log-Based Metrics (from Diagnostic Settings)**

These metrics are provided by Azure when the corresponding diagnostic log categories are enabled.

- <span id="metric-consumer-lag"></span>**Consumer Lag**: The primary metric for measuring backlog is `ConsumerLag` (representing the number of messages), which is sourced from the `ApplicationMetricsLogs` category. This is the measurable metric used for the [Backlog Freshness SLI](#sli-backlog-freshness). The conceptual, business-facing metric is `consumerLagInSeconds` (representing data staleness), from which the alertable threshold for `ConsumerLag` is derived.

**Derived & Predictive Metrics**

- <span id="metric-headroom"></span>**Headroom per Partition ([`Hₚ`](#formula-headroom))**: A predictive metric calculated from `IncomingMessages` and `consumer_processing_time_ms` to forecast potential backlog growth before it occurs. A negative value indicates that the consumer is falling behind.

## 7. Key Design Formulas

- **Processing Unit (PU) Capacity**:
  - `IngressCapacity = Nᵤ × 5 MB/s`
  - `EgressCapacity = Nᵤ × 10 MB/s`
  - _Where `Nᵤ` is the number of provisioned Premium PUs._
    - _Example (for Nᵤ = 2): Ingress is 10 MB/s, Egress is 20 MB/s._
- <span id="formula-rp"></span>**Per-Partition Ingress (`rₚ`)**: `rₚ = Dₑ ÷ P` events/s, where `Dₑ` is the design ceiling event rate and `P` is the partition count.
  - _Example: `3000 events/s ÷ 10 = 300 events/s`_
- <span id="consumer-capacity"></span>**Consumer Capacity (`cₚ`)**: `cₚ = C × (1000 ÷ p95(Tₚ))`, where `C` is consumer concurrency and `p95(Tₚ)` is the 95th percentile consumer processing time.
  - _Example: `4 × (1000 ÷ 10) = 400 events/s`_
- <span id="formula-headroom"></span>**Headroom (`Hₚ`)**: `Hₚ = cₚ − rₚ`.
  - _Example: `400 events/s − 300 events/s = 100`_
- <span id="note-burn-rate"></span>**Error Budget & Burn Rate**:
  - `ErrorBudgetMinutes = Dₛ × 24 × 60 × (1 - (Aₛ / 100))`, where `Dₛ` is the SLO period in days and `Aₛ` is the availability SLO percentage.
    - _Example: `30 × 24 × 60 × (1 - 0.999) = 43.2 minutes`_
  - `BurnRate = (SLO Period ÷ Alert Window) × (Budget % to Consume)`
    - _Critical Burn (15 min window, 2% budget): `(43200 min ÷ 15 min) × 0.02 = 57.6`_
    - _Sustained Burn (6 hr window, 5% budget): `(720 hr ÷ 6 hr) × 0.05 = 6`_
- <span id="backlog-thresholds"></span>**Backlog Thresholds and Clearance**:
  - `LagMessagesCount ≈ [consumer_lag_seconds_threshold](#var-consumer-lag) ×` [`rₚ`](#formula-rp)
    - _Example: `300 seconds × 300 events/s = 90,000 messages`_
  - `TotalBacklogBytes = LagMessagesCount × avg_event_size_bytes`
    - _Example: `90000 × 500 = 45,000,000 bytes`_
  - `EffectiveProcessingRate = min(partition_max_egress_bytes_per_sec, cₚ × avg_event_size_bytes)`
    - _Example: `min(1,000,000, 400 × 500) = 200,000 bytes/s`_
  - `ClearTime ≈ TotalBacklogBytes ÷ EffectiveProcessingRate`
    - _Example: `45,000,000 ÷ 200,000 = 225 seconds`_
  - _**Verification**: The calculated `ClearTime` of 225s is **less than** the 300s threshold ([consumer_lag_seconds_threshold](#var-consumer-lag)), confirming the system has enough capacity to recover from the maximum acceptable lag within the required time._

## 8. Implementation Notes

This section provides guidance on implementing the observability features described in this document.

### Automated Infrastructure Setup (Terraform)
The foundational Azure resources, including the Log Analytics Workspace and the diagnostic settings for the Event Hubs Namespace, can be deployed automatically. The Terraform configuration located in the `deploy/tf` directory is pre-configured to enable all the required log categories. Simply run the [`deploy_local.sh`](../deploy/tf/deploy_local.sh) or [`deploy_remote.sh`](../deploy/tf/deploy_remote.sh) script as appropriate to provision these resources.

Using this script ensures that all log-based metrics from Azure are routed to the correct Log Analytics workspace.

### Understanding Diagnostic Log Categories
Enabling the correct diagnostic logs is crucial for visibility. The Terraform script enables the following categories.

- **`ApplicationMetricsLogs`**:
  - **Purpose**: Provides essential per-partition consumer group lag metrics (`consumerLagInMessages`, `consumerLagInSeconds`).
  - **Why it's needed**: This is the **only** source for the core metrics required for the [Backlog Freshness SLI](#sli-backlog-freshness). Without it, you cannot measure data staleness or consumer performance accurately.

While `ApplicationMetricsLogs` is essential for the performance monitoring described in this document, the Terraform script also enables other valuable log categories for auditing, security, and troubleshooting. These are summarized below. For detailed schema information, refer to the official [Azure Monitor data reference](https://learn.microsoft.com/azure/azure-monitor/reference/tables/tables-by-category#azure-event-hubs).

| Log Category | Purpose |
| :--- | :--- |
| **`OperationalLogs`** | Audits management operations (e.g., creating an Event Hub, updating a consumer group). |
| **`RuntimeAuditLogs`** | Provides security audit trails for data plane access (e.g., client IP, authentication type). |
| **`DiagnosticErrorLogs`** | Captures detailed error information for deep debugging of failed operations. |
| **`EventHubVNetConnectionEvent`** | Tracks VNet and Private Endpoint connection events for network troubleshooting. |

### Custom Metric Instrumentation
The following metrics must be implemented within your application code and emitted to your monitoring backend (e.g., Azure Monitor).

- **`publish_latency_ms` (Producer-side)**:
  - **How**: In your producer application, start a timer immediately before calling the `send` method and stop it upon receiving the acknowledgment from the Event Hubs service.
  - **Why**: This captures the true end-to-end latency experienced by your producers.

- **`consumer_processing_time_ms` (Consumer-side)**:
  - **How**: In your consumer application, start a timer when an event or a batch of events is received and stop it after your business logic for processing that event/batch is complete (including any downstream calls).
  - **Why**: This is essential for diagnosing slow consumers and is a leading indicator of growing consumer lag.

- **`consumer_heartbeat` (Consumer-side)**:
  - **How**: Each active consumer instance should emit a periodic signal (e.g., a gauge or counter metric incremented every [heartbeat_cadence_seconds](#var-heartbeat-cadence) seconds). The metric should include dimensions for the partition ID and consumer group.
  - **Why**: The absence of this signal is the most reliable way to detect a stalled or crashed consumer, as the built-in `consumerLag` metric can become stale in such scenarios. Idle partitions can be identified via supporting metrics when heartbeats persist.

### Additional Notes
- **Distributed Tracing (W3C Trace-Context)**: Enforce W3C trace-context end-to-end. Publish and consume spans should include attributes for enqueue lag and processing duration. Forward traces to Azure Monitor (or a federated backend) and link them from monitoring dashboards to provide full transaction visibility.
- **Metric and Log Tagging**: To accelerate diagnostics, all logs and metrics should be tagged with consistent identifiers, including the Event Hubs namespace, partition ID, consumer group, and the specific workload or application name. This allows for rapid filtering and correlation across different telemetry types.
- **Data Quality Guardrails**: Flag SLIs as having "degraded confidence" if the percentage of missing telemetry signals exceeds a predefined threshold. Enforce a maximum clock skew between clients and servers and alert when the percentage of producers emitting custom telemetry falls below the target coverage.
- **Retry Policies**: While the Azure SDKs include robust retry policies, always confirm that your client-side configuration aligns with the assumptions in this design, particularly around retry windows and backoff strategies.
- **Producer Resilience Patterns**: Consider implementing circuit breaker patterns with local buffering when Event Hubs is unavailable. This prevents data loss by temporarily storing events locally (disk, database) and automatically resuming publishing when the service recovers. For critical systems, evaluate the transactional outbox pattern to ensure atomicity between business operations and event publishing.
- **Upstream Architecture Considerations**: Design upstream systems with resilience in mind. Consider event sourcing patterns where the source of truth includes the unpublished events, allowing for replay scenarios during extended outages. Implement bulkhead isolation to prevent cascade failures across different event streams.

## 9. Cost Guardrails & Optimization

- **Manage Log Analytics Costs**: Proactively manage Log Analytics expenses by setting a default retention period and analyzing data ingestion costs per table (e.g., `ApplicationMetricsLogs`, `OperationalLogs`). Configure Azure Budget alerts on the workspace to prevent unexpected cost overruns.
- **Right-Size Processing Units (PUs)**: Review PU utilization monthly. Use predictive metrics like **Headroom (`Hₚ`)** alongside reactive metrics like `ThrottledRequests` and `IncomingBytes` to make scaling decisions.
  - **Scale-Up Signal**: Consistently low or negative headroom indicates a need to increase PUs or optimize consumer performance.
  - **Scale-Down Signal**: Consistently high headroom suggests the system is over-provisioned and PUs can be reduced to save costs.
- **Optimize Custom Collectors**: Maintain an efficient heartbeat cadence ([heartbeat_cadence_seconds](#var-heartbeat-cadence)) to avoid the cost and complexity of deploying additional custom log collectors unless significant visibility gaps persist.

## 10. Variables

This table lists the core parameters that are referenced in multiple sections of the document, acting as the primary tuning knobs for the observability strategy.

| Variable | Description |
| --- | --- |
| <span id="var-publish-latency"></span>`{{publish_latency_p99_ms}}` | Publish latency SLO (p99). |
| <span id="var-consumer-processing"></span>`{{consumer_processing_p95_ms}}` | Consumer processing latency SLO (p95). |
| <span id="var-consumer-lag"></span>`{{consumer_lag_seconds_threshold}}` | Consumer lag SLO threshold (seconds, p99). |
| <span id="var-connection-headroom"></span>`{{connection_headroom_percent}}` | Maximum allowed namespace connection utilization before scaling. |
| <span id="var-heartbeat-cadence"></span>`{{heartbeat_cadence_seconds}}` | Expected heartbeat cadence per consumer instance. |
