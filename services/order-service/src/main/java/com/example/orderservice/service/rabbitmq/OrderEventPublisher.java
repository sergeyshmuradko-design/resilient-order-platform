package com.example.orderservice.service.rabbitmq;

import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.connection.CorrelationData;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

import com.example.orderservice.configuration.RabbitMqConfig;
import com.example.orderservice.dto.OrderCreatedMessage;

@Service
public class OrderEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(OrderEventPublisher.class);

    private final RabbitTemplate rabbitTemplate;

    public OrderEventPublisher(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;

        this.rabbitTemplate.setConfirmCallback((correlationData, ack, cause) -> {
            String correlationId = correlationData != null ? correlationData.getId() : "unknown";

            if (ack) {
                log.info("RabbitMQ publish confirmed. correlationId={}", correlationId);
            } else {
                log.error("RabbitMQ publish NOT confirmed. correlationId={}, cause={}", correlationId, cause);
            }
        });

        this.rabbitTemplate.setReturnsCallback(returned -> {
            log.error(
                "RabbitMQ message returned. exchange={}, routingKey={}, replyCode={}, replyText={}",
                returned.getExchange(),
                returned.getRoutingKey(),
                returned.getReplyCode(),
                returned.getReplyText()
            );
        });
    }

    public void publishOrderCreated(OrderCreatedMessage message) {
        String correlationId = UUID.randomUUID().toString();
        log.info("Publishing OrderCreated message. orderId={}, correlationId={}", message.orderId(), correlationId);

        rabbitTemplate.convertAndSend(
            RabbitMqConfig.ORDER_EXCHANGE,
            RabbitMqConfig.ORDER_CREATED_ROUTING_KEY,
            message,
            new CorrelationData(correlationId)
        );
    }
}
