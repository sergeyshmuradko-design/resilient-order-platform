package com.example.notificationservice.entity;

import java.time.Instant;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "processed_messages")
public class ProcessedMessageEntity {

    @Id
    private String messageId;

    private Instant processedAt;

    protected ProcessedMessageEntity() {}

    public ProcessedMessageEntity(String messageId) {
        this.messageId = messageId;
        this.processedAt = Instant.now();
    }

	public String getMessageId() {
		return messageId;
	}

	public void setMessageId(String messageId) {
		this.messageId = messageId;
	}

	public Instant getProcessedAt() {
		return processedAt;
	}

	public void setProcessedAt(Instant processedAt) {
		this.processedAt = processedAt;
	}

}
