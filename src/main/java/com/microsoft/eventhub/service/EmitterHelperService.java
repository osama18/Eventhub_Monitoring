// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

package com.microsoft.eventhub.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.microsoft.eventhub.model.EmitterSchema;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.HttpClients;
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
    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final TokenService tokenService;
    
    @Autowired
    public EmitterHelperService(TokenService tokenService) {
        this.httpClient = HttpClients.createDefault();
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
        this.tokenService = tokenService;
    }
    
    public HttpResponse sendCustomMetric(String region, String resourceId, EmitterSchema metricToSend) throws IOException {
        if (region == null || resourceId == null) {
            throw new IllegalArgumentException("Region and resourceId cannot be null");
        }
        
        TokenService.AccessTokenAndExpiration tokenRecord = tokenService.refreshAzureMonitorCredentialOnDemand();
        String uri = String.format("https://%s.monitoring.azure.com%s/metrics", region, resourceId);
        String jsonString = objectMapper.writeValueAsString(metricToSend);
        
        logger.info("SendCustomMetric: {} with payload: {}", uri, jsonString);
        
        HttpPost httpPost = new HttpPost(uri);
        httpPost.setHeader("Authorization", "Bearer " + tokenRecord.getToken());
        httpPost.setHeader("Accept", "application/json");
        httpPost.setHeader("Content-Type", "application/json");
        
        StringEntity entity = new StringEntity(jsonString, "UTF-8");
        httpPost.setEntity(entity);
        
        return httpClient.execute(httpPost);
    }
    
    public String[] getAllConsumerGroups(String eventHubNamespace, String eventHub) throws IOException {
        TokenService.AccessTokenAndExpiration ehRecord = tokenService.refreshAzureEventHubCredentialOnDemand();
        String uri = String.format("https://%s.servicebus.windows.net/%s/consumergroups?timeout=60&api-version=2014-01", 
            eventHubNamespace, eventHub);
        
        logger.info("GetAllConsumerGroup: {}", uri);
        
        HttpGet httpGet = new HttpGet(uri);
        httpGet.setHeader("Authorization", "Bearer " + ehRecord.getToken());
        
        HttpResponse response = httpClient.execute(httpGet);
        HttpEntity entity = response.getEntity();
        String responseBody = EntityUtils.toString(entity);
        
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
            
            return consumerGroups.toArray(new String[0]);
        } catch (Exception e) {
            logger.error("Error parsing consumer groups response", e);
            throw new IOException("Failed to parse consumer groups response", e);
        }
    }
}