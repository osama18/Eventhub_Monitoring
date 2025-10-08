// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

package com.microsoft.eventhub;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

@SpringBootTest
@TestPropertySource(properties = {
    "eventhub.region=test-region",
    "eventhub.subscription-id=test-subscription",
    "eventhub.resource-group=test-rg",
    "eventhub.tenant-id=test-tenant",
    "eventhub.event-hub-namespace=test-namespace",
    "eventhub.event-hub-name=test-eventhub",
    "eventhub.checkpoint-account-name=test-account",
    "eventhub.checkpoint-container-name=test-container"
})
class EventHubCustomMetricsEmitterApplicationTests {

    @Test
    void contextLoads() {
        // Test that the Spring context loads successfully with test configuration
    }
}