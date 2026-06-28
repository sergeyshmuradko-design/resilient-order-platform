package com.example.notificationservice.entity;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "inbox_messages")
public class InboxMessageEntity {

    @Id
    private String messageId;

    @Column(columnDefinition = "TEXT", nullable = false)
    private String payload;

    @Enumerated(EnumType.STRING)
    private InboxMessageStatus status;

    private Instant receivedAt;
    private Instant processedAt;

    @Column(columnDefinition = "TEXT")
    private String errorMessage;

    protected InboxMessageEntity() {
    }

    public InboxMessageEntity(String messageId, String payload) {
        this.messageId = messageId;
        this.payload = payload;
        this.status = InboxMessageStatus.RECEIVED;
        this.receivedAt = Instant.now();
    }

    public String getMessageId() {
        return messageId;
    }

    public void setMessageId(String messageId) {
        this.messageId = messageId;
    }

    public String getPayload() {
        return payload;
    }

    public void setPayload(String payload) {
        this.payload = payload;
    }

    public InboxMessageStatus getStatus() {
        return status;
    }

    public void setStatus(InboxMessageStatus status) {
        this.status = status;
    }

    public Instant getReceivedAt() {
        return receivedAt;
    }

    public void setReceivedAt(Instant receivedAt) {
        this.receivedAt = receivedAt;
    }

    public Instant getProcessedAt() {
        return processedAt;
    }

    public void setProcessedAt(Instant processedAt) {
        this.processedAt = processedAt;
    }

    public void markProcessed() {
        this.status = InboxMessageStatus.PROCESSED;
        this.processedAt = Instant.now();
        this.errorMessage = null;
    }

    public void markFailed(String errorMessage) {
        this.status = InboxMessageStatus.FAILED;
        this.errorMessage = errorMessage;
    }
}
