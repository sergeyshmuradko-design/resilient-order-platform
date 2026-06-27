package com.example.orderservice.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.stereotype.Service;

import com.example.orderservice.dto.OrderCreatedMessage;
import com.example.orderservice.entity.OrderEntity;
import com.example.orderservice.entity.OutboxEventEntity;
import com.example.orderservice.repository.OrderRepository;
import com.example.orderservice.repository.OutboxEventRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import jakarta.transaction.Transactional;

@Service
public class OrderPersistenceService {

    private static final Logger log =
        LoggerFactory.getLogger(OrderPersistenceService.class);

    private final OrderRepository orderRepository;
    private final OutboxEventRepository outboxEventRepository;
    private final ObjectMapper objectMapper;

    public OrderPersistenceService(
        OrderRepository orderRepository,
        OutboxEventRepository outboxEventRepository,
        ObjectMapper objectMapper
    ) {
        this.orderRepository = orderRepository;
        this.outboxEventRepository = outboxEventRepository;
        this.objectMapper = objectMapper;
    }

    @CacheEvict(value = "ordersByCustomerStatus", allEntries = true)
    @Transactional
    public void saveOrder(OrderEntity orderEntity, OrderCreatedMessage message) {
        log.info("Saving order. orderId={}", orderEntity.getOrderId());
        orderRepository.save(orderEntity);
        log.info("Order saved. orderId={}", orderEntity.getOrderId());

        try {
            String payload = objectMapper.writeValueAsString(message);

            OutboxEventEntity event = new OutboxEventEntity(
                message.messageId(),
                "ORDER",
                orderEntity.getOrderId(),
                "OrderCreated",
                payload
            );

            outboxEventRepository.save(event);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Failed to serialize outbox event", e);
        }
    }

    public void saveOrderWithDelay(OrderEntity orderEntity, OrderCreatedMessage message) {
        saveOrder(orderEntity, message);
        simulateSlowWork();
    }

    private void simulateSlowWork() {
        log.info("Strating slow work");

        try {
            Thread.sleep(10000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        log.info("Finished slow work");
    }

    @Transactional
    public void saveOrderWithArtificialDelay(OrderEntity orderEntity) {
        log.info("Saving order with artificial DB delay. orderId={}", orderEntity.getOrderId());
        orderRepository.save(orderEntity);

        try {
            Thread.sleep(10000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        log.info("Finished delayed DB transaction. orderId={}", orderEntity.getOrderId());
    }
}
