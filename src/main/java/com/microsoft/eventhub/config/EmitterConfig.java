// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

package com.microsoft.eventhub.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "eventhub")
public class EmitterConfig {
    
    private String region;
    private String subscriptionId;
    private String resourceGroup;
    private String tenantId;
    private String eventHubNamespace;
    private String eventHubName;
    private String consumerGroup;
    private String checkpointAccountName;
    private String checkpointContainerName;
    private int customMetricInterval = 10000; // default 10 seconds
    private String managedIdentityClientId;
    
    // Getters and Setters
    public String getRegion() {
        return region;
    }
    
    public void setRegion(String region) {
        this.region = region;
    }
    
    public String getSubscriptionId() {
        return subscriptionId;
    }
    
    public void setSubscriptionId(String subscriptionId) {
        this.subscriptionId = subscriptionId;
    }
    
    public String getResourceGroup() {
        return resourceGroup;
    }
    
    public void setResourceGroup(String resourceGroup) {
        this.resourceGroup = resourceGroup;
    }
    
    public String getTenantId() {
        return tenantId;
    }
    
    public void setTenantId(String tenantId) {
        this.tenantId = tenantId;
    }
    
    public String getEventHubNamespace() {
        return eventHubNamespace;
    }
    
    public void setEventHubNamespace(String eventHubNamespace) {
        this.eventHubNamespace = eventHubNamespace;
    }
    
    public String getEventHubName() {
        return eventHubName;
    }
    
    public void setEventHubName(String eventHubName) {
        this.eventHubName = eventHubName;
    }
    
    public String getConsumerGroup() {
        return consumerGroup;
    }
    
    public void setConsumerGroup(String consumerGroup) {
        this.consumerGroup = consumerGroup;
    }
    
    public String getCheckpointAccountName() {
        return checkpointAccountName;
    }
    
    public void setCheckpointAccountName(String checkpointAccountName) {
        this.checkpointAccountName = checkpointAccountName;
    }
    
    public String getCheckpointContainerName() {
        return checkpointContainerName;
    }
    
    public void setCheckpointContainerName(String checkpointContainerName) {
        this.checkpointContainerName = checkpointContainerName;
    }
    
    public int getCustomMetricInterval() {
        return customMetricInterval;
    }
    
    public void setCustomMetricInterval(int customMetricInterval) {
        this.customMetricInterval = customMetricInterval;
    }
    
    public String getManagedIdentityClientId() {
        return managedIdentityClientId;
    }
    
    public void setManagedIdentityClientId(String managedIdentityClientId) {
        this.managedIdentityClientId = managedIdentityClientId;
    }
    
    public void validate() {
        if (isEmpty(region)) throw new IllegalArgumentException("Configuration error, missing key: region");
        if (isEmpty(subscriptionId)) throw new IllegalArgumentException("Configuration error, missing key: subscriptionId");
        if (isEmpty(resourceGroup)) throw new IllegalArgumentException("Configuration error, missing key: resourceGroup");
        if (isEmpty(tenantId)) throw new IllegalArgumentException("Configuration error, missing key: tenantId");
        if (isEmpty(eventHubNamespace)) throw new IllegalArgumentException("Configuration error, missing key: eventHubNamespace");
        if (isEmpty(eventHubName)) throw new IllegalArgumentException("Configuration error, missing key: eventHubName");
        if (isEmpty(checkpointAccountName)) throw new IllegalArgumentException("Configuration error, missing key: checkpointAccountName");
        if (isEmpty(checkpointContainerName)) throw new IllegalArgumentException("Configuration error, missing key: checkpointContainerName");
    }
    
    private boolean isEmpty(String value) {
        return value == null || value.trim().isEmpty();
    }
    
    public String getEventHubResourceId() {
        return String.format("/subscriptions/%s/resourceGroups/%s/providers/Microsoft.EventHub/namespaces/%s", 
            subscriptionId, resourceGroup, eventHubNamespace);
    }
}