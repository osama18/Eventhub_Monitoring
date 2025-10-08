// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

package com.microsoft.eventhub.service;

import com.azure.core.credential.AccessToken;
import com.azure.core.credential.TokenRequestContext;
import com.azure.identity.DefaultAzureCredential;
import com.azure.identity.DefaultAzureCredentialBuilder;
import com.microsoft.eventhub.config.EmitterConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class TokenService {
    
    private static final Logger logger = LoggerFactory.getLogger(TokenService.class);
    private static final String MONITOR_SCOPE = "https://monitor.azure.com/.default";
    private static final String EVENTHUBS_SCOPE = "https://eventhubs.azure.net/.default";
    
    public final DefaultAzureCredential defaultAzureCredential;
    private final ConcurrentHashMap<String, AccessToken> scopeAndTokens = new ConcurrentHashMap<>();
    
    @Autowired
    public TokenService(EmitterConfig config) {
        DefaultAzureCredentialBuilder builder = new DefaultAzureCredentialBuilder();
        
        String tenantId = config.getTenantId();
        String managedIdentityClientId = config.getManagedIdentityClientId();
        
        if (tenantId != null && !tenantId.trim().isEmpty()) {
            logger.info("Configuring TokenService with tenant ID: {}", tenantId);
            builder.tenantId(tenantId);
        }
        
        if (managedIdentityClientId != null && !managedIdentityClientId.trim().isEmpty()) {
            logger.info("Configuring TokenService with managed identity client ID: {}", managedIdentityClientId);
            builder.managedIdentityClientId(managedIdentityClientId);
        } else {
            logger.info("Configuring TokenService with default Azure credential");
        }
        
        this.defaultAzureCredential = builder.build();
        logger.info("TokenService initialized successfully");
        // Initialize tokens
        refreshAzureMonitorCredentialOnDemand();
        refreshAzureEventHubCredentialOnDemand();
    }
    
    public AccessTokenAndExpiration refreshAzureMonitorCredentialOnDemand() {
        return refreshCredentialOnDemand(MONITOR_SCOPE);
    }
    
    public AccessTokenAndExpiration refreshAzureEventHubCredentialOnDemand() {
        return refreshCredentialOnDemand(EVENTHUBS_SCOPE);
    }
    
    private AccessTokenAndExpiration refreshCredentialOnDemand(String scope) {
        boolean isExpired = needsNewToken(scope, Duration.ofMinutes(5));
        
        if (isExpired) {
            try {
                TokenRequestContext tokenRequestContext = new TokenRequestContext().addScopes(scope);
                AccessToken newToken = defaultAzureCredential.getToken(tokenRequestContext).block();
                
                if (newToken != null) {
                    scopeAndTokens.put(scope, newToken);
                    logger.debug("Successfully refreshed token for scope: {}", scope);
                } else {
                    logger.error("Failed to get token for scope: {}", scope);
                }
            } catch (Exception e) {
                logger.error("Error refreshing credential for scope: {}", scope, e);
                throw new RuntimeException("Failed to refresh credential", e);
            }
        }
        
        AccessToken token = scopeAndTokens.get(scope);
        return new AccessTokenAndExpiration(isExpired, token != null ? token.getToken() : null);
    }
    
    private boolean needsNewToken(String scope, Duration safetyInterval) {
        AccessToken token = scopeAndTokens.get(scope);
        if (token == null) {
            return true;
        }
        
        Duration timeUntilExpiry = Duration.between(OffsetDateTime.now(), token.getExpiresAt());
        return timeUntilExpiry.compareTo(safetyInterval) < 0;
    }
    
    public static class AccessTokenAndExpiration {
        private final boolean isExpired;
        private final String token;
        
        public AccessTokenAndExpiration(boolean isExpired, String token) {
            this.isExpired = isExpired;
            this.token = token;
        }
        
        public boolean isExpired() {
            return isExpired;
        }
        
        public String getToken() {
            return token;
        }
    }
}