// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

package com.microsoft.eventhub;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class EventHubCustomMetricsEmitterApplication {

    public static void main(String[] args) {
        SpringApplication.run(EventHubCustomMetricsEmitterApplication.class, args);
    }
}