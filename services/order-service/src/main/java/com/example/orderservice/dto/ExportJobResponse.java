package com.example.orderservice.dto;

import java.time.Instant;

import com.example.orderservice.entity.ExportJobEntity;
import com.example.orderservice.entity.ExportJobStatus;

public record ExportJobResponse(
    String jobId,
    String statusFilter,
    ExportJobStatus status,
    String errorMessage,
    Instant createdAt,
    Instant startedAt,
    Instant completedAt
) {
    public static ExportJobResponse from(ExportJobEntity entity) {
        return new ExportJobResponse(
            entity.getJobId(),
            entity.getStatusFilter(),
            entity.getStatus(),
            entity.getErrorMessage(),
            entity.getCreatedAt(),
            entity.getStartedAt(),
            entity.getCompletedAt()
        );
    }
}
