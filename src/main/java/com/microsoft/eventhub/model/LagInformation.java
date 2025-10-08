// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

package com.microsoft.eventhub.model;

public class LagInformation {
    private final String consumerName;
    private final String partitionId;
    private final long lag;
    
    public LagInformation(String consumerName, String partitionId, long lag) {
        this.consumerName = consumerName;
        this.partitionId = partitionId;
        this.lag = lag;
    }
    
    public String getConsumerName() {
        return consumerName;
    }
    
    public String getPartitionId() {
        return partitionId;
    }
    
    public long getLag() {
        return lag;
    }
    
    @Override
    public String toString() {
        return String.format("LagInformation{consumerName='%s', partitionId='%s', lag=%d}", 
            consumerName, partitionId, lag);
    }
}