// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

package com.microsoft.eventhub.service;

import com.azure.messaging.eventhubs.EventHubConsumerAsyncClient;
import com.azure.messaging.eventhubs.EventHubClientBuilder;
import com.azure.messaging.eventhubs.PartitionProperties;
import com.azure.storage.blob.BlobClient;
import com.azure.storage.blob.BlobContainerClient;
import com.azure.storage.blob.BlobContainerClientBuilder;
import com.azure.storage.blob.models.BlobProperties;
import com.microsoft.eventhub.config.EmitterConfig;
import com.microsoft.eventhub.model.EmitterSchema;
import com.microsoft.eventhub.model.LagInformation;
import org.apache.http.HttpResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import javax.annotation.PostConstruct;
import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.stream.Collectors;

@Service
public class EventHubEmitterService {
    
    private static final Logger logger = LoggerFactory.getLogger(EventHubEmitterService.class);
    private static final String LAG_METRIC_NAME = "Lag";
    private static final String EVENT_HUB_CUSTOM_METRIC_NAMESPACE = "Event Hub custom metrics";
    private static final String SEQUENCE_NUMBER = "sequencenumber";
    private static final String OFFSET_KEY = "offset";
    private static final String SERVICE_BUS_HOST_SUFFIX = ".servicebus.windows.net";
    private static final String STORAGE_HOST_SUFFIX = ".blob.core.windows.net";
    
    private final EmitterConfig config;
    private final EmitterHelperService emitterHelper;
    private final TokenService tokenService;
    
    private String eventHubResourceId;
    private String prefix;
    private BlobContainerClient checkpointContainerClient;
    private Map<String, ConsumerClientInfo> eventHubConsumerClientsInfo = new ConcurrentHashMap<>();
    private String[] consumerGroups;
    
    @Autowired
    public EventHubEmitterService(EmitterConfig config, EmitterHelperService emitterHelper, TokenService tokenService) {
        this.config = config;
        this.emitterHelper = emitterHelper;
        this.tokenService = tokenService;
    }
    
    @PostConstruct
    public void initialize() {
        try {
            config.validate();
            
            // Determine consumer groups
            if (config.getConsumerGroup() == null || config.getConsumerGroup().trim().isEmpty()) {
                consumerGroups = emitterHelper.getAllConsumerGroups(config.getEventHubNamespace(), config.getEventHubName());
            } else {
                consumerGroups = config.getConsumerGroup().split(";");
            }
            
            eventHubResourceId = config.getEventHubResourceId();
            prefix = String.format("%s%s/%s", 
                config.getEventHubNamespace().toLowerCase(), 
                SERVICE_BUS_HOST_SUFFIX, 
                config.getEventHubName().toLowerCase());
            
            // Initialize blob container client
            String blobContainerUri = String.format("https://%s%s/%s", 
                config.getCheckpointAccountName(), 
                STORAGE_HOST_SUFFIX, 
                config.getCheckpointContainerName());
                
            checkpointContainerClient = new BlobContainerClientBuilder()
                .endpoint(blobContainerUri)
                .credential(tokenService.defaultAzureCredential)
                .buildClient();
            
            // Initialize EventHub consumer clients per consumer group
            for (String consumerGroup : consumerGroups) {
                EventHubConsumerAsyncClient client = new EventHubClientBuilder()
                    .consumerGroup(consumerGroup)
                    .fullyQualifiedNamespace(config.getEventHubNamespace().toLowerCase() + SERVICE_BUS_HOST_SUFFIX)
                    .eventHubName(config.getEventHubName())
                    .credential(tokenService.defaultAzureCredential)
                    .buildAsyncConsumerClient();
                
                // Get partition IDs with timeout
                String[] partitionIds = client.getPartitionIds().collectList()
                    .block(Duration.ofSeconds(10))
                    .toArray(new String[0]);
                
                eventHubConsumerClientsInfo.put(consumerGroup, new ConsumerClientInfo(client, partitionIds));
            }
            
            logger.info("EventHubEmitterService initialized successfully with {} consumer groups", consumerGroups.length);
        } catch (Exception e) {
            logger.error("Failed to initialize EventHubEmitterService", e);
            throw new RuntimeException("Initialization failed", e);
        }
    }
    
    public HttpResponse readFromBlobStorageAndPublishToAzureMonitor() throws IOException {
        List<LagInformation> totalLag = getLag();
        
        // Log summary of lag across all partitions
        long totalLagSum = totalLag.stream().mapToLong(LagInformation::getLag).sum();
        logger.info("=== Lag Summary: Total lag across all partitions: {} events ===", totalLagSum);
        
        List<String> dimNames = Arrays.asList("EventHubName", "ConsumerGroup", "PartitionId");
        List<EmitterSchema.CustomMetricBaseDataSeriesItem> series = new ArrayList<>();
        
        for (int i = 0; i < totalLag.size(); i++) {
            LagInformation lagInfo = totalLag.get(i);
            List<String> dimValues = Arrays.asList(
                config.getEventHubName(), 
                lagInfo.getConsumerName(), 
                lagInfo.getPartitionId()
            );
            
            series.add(new EmitterSchema.CustomMetricBaseDataSeriesItem(
                dimValues, null, null, lagInfo.getLag(), (long) (i + 1)
            ));
        }
        
        EmitterSchema.CustomMetricBaseData baseData = new EmitterSchema.CustomMetricBaseData(
            LAG_METRIC_NAME, EVENT_HUB_CUSTOM_METRIC_NAMESPACE, dimNames, series
        );
        
        EmitterSchema.CustomMetricData data = new EmitterSchema.CustomMetricData(baseData);
        EmitterSchema emitterData = new EmitterSchema(Instant.now(), data);
        
        return emitterHelper.sendCustomMetric(config.getRegion(), eventHubResourceId, emitterData);
    }
    
    private List<LagInformation> getLag() {
        // Query all partitions in parallel
        List<CompletableFuture<LagInformation>> tasks = new ArrayList<>();
        
        for (String consumerGroup : consumerGroups) {
            ConsumerClientInfo clientInfo = eventHubConsumerClientsInfo.get(consumerGroup);
            for (String partitionId : clientInfo.getPartitionIds()) {
                CompletableFuture<LagInformation> task = CompletableFuture.supplyAsync(() -> {
                    try {
                        long lag = lagInPartition(consumerGroup, partitionId);
                        logger.info("Calculated lag for ConsumerGroup='{}' Partition='{}': {} events", 
                            consumerGroup, partitionId, lag);
                        return new LagInformation(consumerGroup, partitionId, lag);
                    } catch (Exception e) {
                        logger.error("Error calculating lag for consumer group {} partition {}", consumerGroup, partitionId, e);
                        return new LagInformation(consumerGroup, partitionId, 0L);
                    }
                });
                tasks.add(task);
            }
        }
        
        // Wait for all tasks to complete with timeout
        CompletableFuture<Void> allTasks = CompletableFuture.allOf(tasks.toArray(new CompletableFuture[0]));
        try {
            allTasks.get(30, TimeUnit.SECONDS);
        } catch (TimeoutException e) {
            logger.error("Timeout waiting for lag calculation tasks to complete", e);
            // Cancel incomplete tasks
            tasks.forEach(task -> task.cancel(true));
            throw new RuntimeException("Timeout calculating lag for partitions", e);
        } catch (Exception e) {
            logger.error("Error waiting for lag calculation tasks", e);
            throw new RuntimeException("Error calculating lag for partitions", e);
        }
        
        return tasks.stream()
            .map(CompletableFuture::join)
            .sorted(Comparator.comparing(LagInformation::getPartitionId))
            .collect(Collectors.toList());
    }
    
    private long lagInPartition(String consumerGroup, String partitionId) {
        long retVal = 0;
        try {
            ConsumerClientInfo clientInfo = eventHubConsumerClientsInfo.get(consumerGroup);
            PartitionProperties partitionInfo = clientInfo.getConsumerClient()
                .getPartitionProperties(partitionId)
                .block(Duration.ofSeconds(10));
                
            if (partitionInfo != null && "-1".equals(partitionInfo.getLastEnqueuedOffset())) {
                logger.info("LagInPartition Empty partition");
            } else {
                String checkpointName = getCheckpointBlobName(consumerGroup, partitionId);
                logger.info("LagInPartition Checkpoint GetProperties: {}", checkpointName);
                
                BlobClient blobClient = checkpointContainerClient.getBlobClient(checkpointName);
                BlobProperties properties = blobClient.getProperties();
                
                Map<String, String> metadata = properties.getMetadata();
                String strSeqNum = metadata.get(SEQUENCE_NUMBER);
                String strOffset = metadata.get(OFFSET_KEY);
                
                if (strSeqNum != null && strOffset != null) {
                    try {
                        long seqNum = Long.parseLong(strSeqNum);
                        logger.info("LagInPartition Start: {} seq={} offset={}", checkpointName, seqNum, strOffset);
                        
                        // If checkpoint.Offset is empty that means no messages has been processed from an event hub partition
                        // And since partitionInfo.LastSequenceNumber = 0 for the very first message hence
                        // total unprocessed message will be partitionInfo.LastSequenceNumber + 1
                        if (strOffset == null || strOffset.trim().isEmpty()) {
                            retVal = partitionInfo.getLastEnqueuedSequenceNumber() + 1;
                        } else {
                            if (partitionInfo.getLastEnqueuedSequenceNumber() >= seqNum) {
                                retVal = partitionInfo.getLastEnqueuedSequenceNumber() - seqNum;
                            } else {
                                // Partition is a circular buffer, so it is possible that
                                // partitionInfo.LastSequenceNumber < blob checkpoint's SequenceNumber
                                retVal = (Long.MAX_VALUE - partitionInfo.getLastEnqueuedSequenceNumber()) + seqNum;
                                
                                if (retVal < 0) {
                                    retVal = 0;
                                }
                            }
                        }
                        logger.info("LagInPartition End: {} seq={} offset={} lag={}", checkpointName, seqNum, strOffset, retVal);
                    } catch (NumberFormatException e) {
                        logger.error("Error parsing sequence number: {}", strSeqNum, e);
                    }
                }
            }
        } catch (Exception e) {
            logger.error("LagInPartition Error: ", e);
        }
        return retVal;
    }
    
    private String getCheckpointBlobName(String consumerGroup, String partitionId) {
        return String.format("%s/%s/checkpoint/%s", prefix, consumerGroup.toLowerCase(), partitionId);
    }
    
    private static class ConsumerClientInfo {
        private final EventHubConsumerAsyncClient consumerClient;
        private final String[] partitionIds;
        
        public ConsumerClientInfo(EventHubConsumerAsyncClient consumerClient, String[] partitionIds) {
            this.consumerClient = consumerClient;
            this.partitionIds = partitionIds;
        }
        
        public EventHubConsumerAsyncClient getConsumerClient() {
            return consumerClient;
        }
        
        public String[] getPartitionIds() {
            return partitionIds;
        }
    }
}