// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

package com.microsoft.eventhub.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.Instant;
import java.util.List;

// Based on: https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/metrics-store-custom-rest-api

public class EmitterSchema {
    @JsonProperty("time")
    private Instant time;
    
    @JsonProperty("data")
    private CustomMetricData data;
    
    public EmitterSchema() {}
    
    public EmitterSchema(Instant time, CustomMetricData data) {
        this.time = time;
        this.data = data;
    }
    
    public Instant getTime() {
        return time;
    }
    
    public void setTime(Instant time) {
        this.time = time;
    }
    
    public CustomMetricData getData() {
        return data;
    }
    
    public void setData(CustomMetricData data) {
        this.data = data;
    }
    
    public static class CustomMetricData {
        @JsonProperty("baseData")
        private CustomMetricBaseData baseData;
        
        public CustomMetricData() {}
        
        public CustomMetricData(CustomMetricBaseData baseData) {
            this.baseData = baseData;
        }
        
        public CustomMetricBaseData getBaseData() {
            return baseData;
        }
        
        public void setBaseData(CustomMetricBaseData baseData) {
            this.baseData = baseData;
        }
    }
    
    public static class CustomMetricBaseData {
        @JsonProperty("metric")
        private String metric;
        
        @JsonProperty("namespace")
        private String namespace;
        
        @JsonProperty("dimNames")
        private List<String> dimNames;
        
        @JsonProperty("series")
        private List<CustomMetricBaseDataSeriesItem> series;
        
        public CustomMetricBaseData() {}
        
        public CustomMetricBaseData(String metric, String namespace, List<String> dimNames, List<CustomMetricBaseDataSeriesItem> series) {
            this.metric = metric;
            this.namespace = namespace;
            this.dimNames = dimNames;
            this.series = series;
        }
        
        public String getMetric() {
            return metric;
        }
        
        public void setMetric(String metric) {
            this.metric = metric;
        }
        
        public String getNamespace() {
            return namespace;
        }
        
        public void setNamespace(String namespace) {
            this.namespace = namespace;
        }
        
        public List<String> getDimNames() {
            return dimNames;
        }
        
        public void setDimNames(List<String> dimNames) {
            this.dimNames = dimNames;
        }
        
        public List<CustomMetricBaseDataSeriesItem> getSeries() {
            return series;
        }
        
        public void setSeries(List<CustomMetricBaseDataSeriesItem> series) {
            this.series = series;
        }
    }
    
    public static class CustomMetricBaseDataSeriesItem {
        @JsonProperty("dimValues")
        private List<String> dimValues;
        
        @JsonProperty("min")
        @JsonIgnore
        private Long min; // Ignored when null
        
        @JsonProperty("max")
        @JsonIgnore
        private Long max; // Ignored when null
        
        @JsonProperty("sum")
        private Long sum;
        
        @JsonProperty("count")
        private Long count;
        
        public CustomMetricBaseDataSeriesItem() {}
        
        public CustomMetricBaseDataSeriesItem(List<String> dimValues, Long min, Long max, Long sum, Long count) {
            this.dimValues = dimValues;
            this.min = min;
            this.max = max;
            this.sum = sum;
            this.count = count;
        }
        
        public List<String> getDimValues() {
            return dimValues;
        }
        
        public void setDimValues(List<String> dimValues) {
            this.dimValues = dimValues;
        }
        
        public Long getMin() {
            return min;
        }
        
        public void setMin(Long min) {
            this.min = min;
        }
        
        public Long getMax() {
            return max;
        }
        
        public void setMax(Long max) {
            this.max = max;
        }
        
        public Long getSum() {
            return sum;
        }
        
        public void setSum(Long sum) {
            this.sum = sum;
        }
        
        public Long getCount() {
            return count;
        }
        
        public void setCount(Long count) {
            this.count = count;
        }
    }
}