package com.example.notificationservice.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import com.example.notificationservice.dto.OrderCreatedMessage;
import com.example.notificationservice.entity.InboxMessageEntity;
import com.example.notificationservice.repository.InboxMessageRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

@Service
public class IdempotentNotificationService {

    private static final Logger log = LoggerFactory.getLogger(IdempotentNotificationService.class);

    @PersistenceContext
    private EntityManager entityManager;

    private final InboxMessageRepository inboxMessageRepository;
    private final ObjectMapper objectMapper;

	public IdempotentNotificationService(
        InboxMessageRepository inboxMessageRepository,
        ObjectMapper objectMapper
    ) {
		this.inboxMessageRepository = inboxMessageRepository;
        this.objectMapper = objectMapper;
	}

    @Transactional
    public boolean tryProcess(OrderCreatedMessage message) {
        if (inboxMessageRepository.existsById(message.messageId())) {
            return false;
        }

        InboxMessageEntity inboxMessage = new InboxMessageEntity(
            message.messageId(),
            toJson(message)
        );

        log.info("Transaction active: {}", TransactionSynchronizationManager.isActualTransactionActive());

        InboxMessageEntity saved = inboxMessageRepository.save(inboxMessage); // because of manual messageId setting persistence context use merge which manage the returned object instead of the original

        log.info("Entity managed after save: {}", entityManager.contains(saved));

        saved.markProcessed();

        log.info("Entity managed after markProcessed: {}", entityManager.contains(saved));

        return true;
    }

    private String toJson(OrderCreatedMessage message) {
        try {
            return objectMapper.writeValueAsString(message);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Failed to serialize inbox message", e);
        }
    }
}
