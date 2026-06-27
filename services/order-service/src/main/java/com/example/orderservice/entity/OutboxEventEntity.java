package com.example.orderservice.entity;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "outbox_events")
public class OutboxEventEntity {

    @Id
    private String eventId;

    private String aggregateType;
    private String aggregateId;
    private String eventType;

    @Column(columnDefinition = "TEXT")
    private String payload;

    @Enumerated(EnumType.STRING)
    private OutboxEventStatus status;

    private int retryCount;

    @Column(columnDefinition = "TEXT")
    private String lastError;

    private Instant nextRetryAt;

    private Instant createdAt;
    private Instant publishedAt;

    protected OutboxEventEntity() {
    }

    public OutboxEventEntity(String eventId, String aggregateType, String aggregateId, String eventType, String payload) {
        this.eventId = eventId;
        this.aggregateType = aggregateType;
        this.aggregateId = aggregateId;
        this.eventType = eventType;
        this.payload = payload;
        this.status = OutboxEventStatus.NEW;
        this.retryCount = 0;
        this.createdAt = Instant.now();
        this.nextRetryAt = Instant.now();
    }

    public String getEventId() {
        return eventId;
    }

    public void setEventId(String eventId) {
        this.eventId = eventId;
    }

    public String getAggregateType() {
        return aggregateType;
    }

    public void setAggregateType(String aggregateType) {
        this.aggregateType = aggregateType;
    }

    public String getAggregateId() {
        return aggregateId;
    }

    public void setAggregateId(String aggregateId) {
        this.aggregateId = aggregateId;
    }

    public String getEventType() {
        return eventType;
    }

    public void setEventType(String eventType) {
        this.eventType = eventType;
    }

    public String getPayload() {
        return payload;
    }

    public void setPayload(String payload) {
        this.payload = payload;
    }

    public OutboxEventStatus getStatus() {
        return status;
    }

    public void setStatus(OutboxEventStatus status) {
        this.status = status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getPublishedAt() {
        return publishedAt;
    }

    public void setPublishedAt(Instant publishedAt) {
        this.publishedAt = publishedAt;
    }

    public int getRetryCount() {
		return retryCount;
	}

	public void setRetryCount(int retryCount) {
		this.retryCount = retryCount;
	}

	public String getLastError() {
		return lastError;
	}

	public void setLastError(String lastError) {
		this.lastError = lastError;
	}

	public Instant getNextRetryAt() {
		return nextRetryAt;
	}

	public void setNextRetryAt(Instant nextRetryAt) {
		this.nextRetryAt = nextRetryAt;
	}

	public void markPublished() {
        this.status = OutboxEventStatus.PUBLISHED;
        this.publishedAt = Instant.now();
    }

    public void markProcessing() {
        this.status = OutboxEventStatus.PROCESSING;
    }

    public void markReturned(String errorMessage) {
        this.status = OutboxEventStatus.RETURNED;
        this.lastError = errorMessage;
    }

    public void markFailed(String errorMessage) {
        this.retryCount++;
        this.lastError = errorMessage;

        if (this.retryCount >= 3) {
            this.status = OutboxEventStatus.FAILED;
            return;
        }

        this.status = OutboxEventStatus.NEW;
        this.nextRetryAt = Instant.now().plusSeconds(30L * retryCount);
    }
}
