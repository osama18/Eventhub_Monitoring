// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

package com.microsoft.eventhub.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.microsoft.eventhub.model.EmitterSchema;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.config.RequestConfig;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.impl.conn.PoolingHttpClientConnectionManager;
import org.apache.http.util.EntityUtils;
import org.dom4j.Document;
import org.dom4j.DocumentHelper;
import org.dom4j.Element;
import org.dom4j.Node;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

@Service
public class EmitterHelperService {
    
    private static final Logger logger = LoggerFactory.getLogger(EmitterHelperService.class);
    private final CloseableHttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final TokenService tokenService;
    
    @Autowired
    public EmitterHelperService(TokenService tokenService) {
        // Configure connection pool manager to prevent connection exhaustion
        PoolingHttpClientConnectionManager connectionManager = new PoolingHttpClientConnectionManager();
        connectionManager.setMaxTotal(50);              // Maximum total connections
        connectionManager.setDefaultMaxPerRoute(10);     // Maximum connections per route
        
        // Configure timeouts for HTTP client to prevent hanging requests
        RequestConfig requestConfig = RequestConfig.custom()
            .setConnectTimeout(10000)        // 10 seconds to establish connection
            .setSocketTimeout(30000)         // 30 seconds to wait for data
            .setConnectionRequestTimeout(10000) // 10 seconds to get connection from pool
            .build();
            
        this.httpClient = HttpClients.custom()
            .setConnectionManager(connectionManager)
            .setDefaultRequestConfig(requestConfig)
            .build();
            
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
        // Serialize dates as ISO 8601 strings instead of timestamps
        this.objectMapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        this.tokenService = tokenService;
    }
    
    public HttpResponse sendCustomMetric(String region, String resourceId, EmitterSchema metricToSend) throws IOException {
        if (region == null || resourceId == null) {
            throw new IllegalArgumentException("Region and resourceId cannot be null");
        }
        
        long startTime = System.currentTimeMillis();
        String uri = "";
        
        try {
            TokenService.AccessTokenAndExpiration tokenRecord = tokenService.refreshAzureMonitorCredentialOnDemand();
            uri = String.format("https://%s.monitoring.azure.com%s/metrics", region, resourceId);
            String jsonString = objectMapper.writeValueAsString(metricToSend);
            
            logger.info("SendCustomMetric: {} with payload: {}", uri, jsonString);
            
            HttpPost httpPost = new HttpPost(uri);
            httpPost.setHeader("Authorization", "Bearer " + tokenRecord.getToken());
            httpPost.setHeader("Accept", "application/json");
            httpPost.setHeader("Content-Type", "application/json");
            
            StringEntity entity = new StringEntity(jsonString, "UTF-8");
            httpPost.setEntity(entity);
            
            logger.info("SendCustomMetric - About to execute HTTP POST to {}", uri);
            HttpResponse response = httpClient.execute(httpPost);
            long duration = System.currentTimeMillis() - startTime;
            
            int statusCode = response.getStatusLine().getStatusCode();
            logger.info("SendCustomMetric - HTTP POST completed in {}ms with status code: {}", duration, statusCode);
            
            // Consume the response entity to release the connection back to the pool
            EntityUtils.consumeQuietly(response.getEntity());
            
            return response;
        } catch (Exception e) {
            long duration = System.currentTimeMillis() - startTime;
            logger.error("SendCustomMetric - Failed after {}ms for URI: {}. Error: {}", duration, uri, e.getMessage(), e);
            throw e;
        }
    }
    
    public String[] getAllConsumerGroups(String eventHubNamespace, String eventHub) throws IOException {
        long startTime = System.currentTimeMillis();
        String uri = "";
        
        try {
            TokenService.AccessTokenAndExpiration ehRecord = tokenService.refreshAzureEventHubCredentialOnDemand();
            uri = String.format("https://%s.servicebus.windows.net/%s/consumergroups?timeout=60&api-version=2014-01", 
                eventHubNamespace, eventHub);
            
            logger.info("GetAllConsumerGroup: {}", uri);
            
            HttpGet httpGet = new HttpGet(uri);
            httpGet.setHeader("Authorization", "Bearer " + ehRecord.getToken());
            
            logger.info("GetAllConsumerGroup - About to execute HTTP GET to {}", uri);
            HttpResponse response = httpClient.execute(httpGet);
            long duration = System.currentTimeMillis() - startTime;
            
            int statusCode = response.getStatusLine().getStatusCode();
            logger.info("GetAllConsumerGroup - HTTP GET completed in {}ms with status code: {}", duration, statusCode);
            
            HttpEntity entity = response.getEntity();
            String responseBody = EntityUtils.toString(entity);
            // Consume entity to release connection back to pool
            EntityUtils.consumeQuietly(entity);
            
            try {
                Document doc = DocumentHelper.parseText(responseBody);
                Element root = doc.getRootElement();
                
                List<String> consumerGroups = new ArrayList<>();
                List<Node> entries = root.selectNodes("//entry/title");
                
                for (Node node : entries) {
                    Element titleElement = (Element) node;
                    String consumerGroupName = titleElement.getTextTrim();
                    if (!consumerGroupName.isEmpty()) {
                        consumerGroups.add(consumerGroupName);
                    }
                }
                
                logger.info("GetAllConsumerGroup - Successfully parsed {} consumer groups", consumerGroups.size());
                return consumerGroups.toArray(new String[0]);
            } catch (Exception e) {
                logger.error("GetAllConsumerGroup - Error parsing consumer groups response", e);
                throw new IOException("Failed to parse consumer groups response", e);
            }
        } catch (IOException e) {
            long duration = System.currentTimeMillis() - startTime;
            logger.error("GetAllConsumerGroup - Failed after {}ms for URI: {}. Error: {}", duration, uri, e.getMessage(), e);
            throw e;
        }
    }
}