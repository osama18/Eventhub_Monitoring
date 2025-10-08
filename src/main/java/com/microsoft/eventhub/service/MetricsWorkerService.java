// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

package com.microsoft.eventhub.service;

import com.microsoft.eventhub.config.EmitterConfig;
import org.apache.http.HttpResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;

@Service
public class MetricsWorkerService {
    
    private static final Logger logger = LoggerFactory.getLogger(MetricsWorkerService.class);
    
    private final EventHubEmitterService eventHubEmitterService;
    private final EmitterConfig config;
    
    @Autowired
    public MetricsWorkerService(EventHubEmitterService eventHubEmitterService, EmitterConfig config) {
        this.eventHubEmitterService = eventHubEmitterService;
        this.config = config;
    }
    
    @Scheduled(fixedDelayString = "#{emitterConfig.customMetricInterval}")
    public void executeMetricsCollection() {
        try {
            logger.info("Worker running at: {}", OffsetDateTime.now());
            
            HttpResponse response = eventHubEmitterService.readFromBlobStorageAndPublishToAzureMonitor();
            int statusCode = response.getStatusLine().getStatusCode();
            
            if (statusCode >= 200 && statusCode < 300) {
                logger.info("Send Custom Metric end with status: {}", statusCode);
            } else {
                logger.error("Error sending custom event with status: {}", statusCode);
            }
            
        } catch (Exception e) {
            logger.error("Error in metrics collection worker", e);
        }
    }
}