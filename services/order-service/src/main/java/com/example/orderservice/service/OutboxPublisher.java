package com.example.orderservice.service;

import java.time.Instant;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.orderservice.dto.OrderCreatedMessage;
import com.example.orderservice.entity.OutboxEventEntity;
import com.example.orderservice.entity.OutboxEventStatus;
import com.example.orderservice.repository.OutboxEventRepository;
import com.example.orderservice.service.rabbitmq.OrderEventPublisher;
import com.fasterxml.jackson.databind.ObjectMapper;

@Service
public class OutboxPublisher {

    private static final Logger log = LoggerFactory.getLogger(OutboxPublisher.class);

    private final OutboxEventRepository outboxEventRepository;
    private final OrderEventPublisher orderEventPublisher;
    private final ObjectMapper objectMapper;

    public OutboxPublisher(OutboxEventRepository outboxEventRepository, OrderEventPublisher orderEventPublisher,
            ObjectMapper objectMapper) {
        this.outboxEventRepository = outboxEventRepository;
        this.orderEventPublisher = orderEventPublisher;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public void publishNewEvents() {
        List<OutboxEventEntity> events =
            outboxEventRepository.findTop20ByStatusAndNextRetryAtLessThanEqualOrderByCreatedAtAsc(OutboxEventStatus.NEW, Instant.now());

        for (OutboxEventEntity event : events) {
            try {
                OrderCreatedMessage message =
                    objectMapper.readValue(event.getPayload(), OrderCreatedMessage.class);

                event.markProcessing();
                outboxEventRepository.saveAndFlush(event); // TODO: Fix sync calls

                orderEventPublisher.publishOrderCreated(event.getEventId(), message);
            } catch (Exception e) {
                log.error("Failed to publish outbox event. eventId={}", event.getEventId(), e);
                event.markFailed(e.getMessage());
            }
        }
    }
}
