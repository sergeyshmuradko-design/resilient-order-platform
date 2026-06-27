package com.example.orderservice.service.rabbitmq;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.connection.CorrelationData;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

import com.example.orderservice.configuration.RabbitMqConfig;
import com.example.orderservice.dto.OrderCreatedMessage;
import com.example.orderservice.service.OutboxEventService;

@Service
public class OrderEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(OrderEventPublisher.class);

    private final RabbitTemplate rabbitTemplate;

    public OrderEventPublisher(RabbitTemplate rabbitTemplate, OutboxEventService outboxEventService) {
        this.rabbitTemplate = rabbitTemplate;

        this.rabbitTemplate.setConfirmCallback((correlationData, ack, cause) -> {
            if (correlationData == null) {
                return;
            }

            String eventId = correlationData.getId();

            if (ack) {
                log.info("RabbitMQ publish confirmed. eventId={}", eventId);
                outboxEventService.markPublished(eventId);
            } else {
                log.error("RabbitMQ publish NOT confirmed. eventId={}, cause={}", eventId, cause);
                outboxEventService.markPublishFailed(eventId, cause);
            }
        });

        this.rabbitTemplate.setReturnsCallback(returned -> {
            String eventId = returned.getMessage()
                .getMessageProperties()
                .getCorrelationId();

            log.error(
                "RabbitMQ message returned. eventId={}, exchange={}, routingKey={}, replyText={}",
                eventId,
                returned.getExchange(),
                returned.getRoutingKey(),
                returned.getReplyText()
            );

            if (eventId != null) {
                outboxEventService.markReturned(eventId, "Message returned: " + returned.getReplyText());
            }
        });
    }

    public void publishOrderCreated(String eventId, OrderCreatedMessage message) {
        CorrelationData correlationData = new CorrelationData(eventId);

        log.info("Publishing OrderCreated message. orderId={}, eventId={}", message.orderId(), eventId);

        rabbitTemplate.convertAndSend(
            RabbitMqConfig.ORDER_EXCHANGE,
            RabbitMqConfig.ORDER_CREATED_ROUTING_KEY,
            message,
            rabbitMessage -> {
                rabbitMessage.getMessageProperties().setCorrelationId(eventId);
                return rabbitMessage;
            },
            correlationData
        );
    }
}
