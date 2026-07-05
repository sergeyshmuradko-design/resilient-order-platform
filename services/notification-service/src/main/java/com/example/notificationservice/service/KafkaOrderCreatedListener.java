package com.example.notificationservice.service;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

import com.example.notificationservice.dto.OrderCreatedMessage;

@Component
public class KafkaOrderCreatedListener {

    private static final Logger log = LoggerFactory.getLogger(KafkaOrderCreatedListener.class);

    private final IdempotentNotificationService idempotentNotificationService;

    public KafkaOrderCreatedListener(IdempotentNotificationService idempotentNotificationService) {
		this.idempotentNotificationService = idempotentNotificationService;
	}

    @KafkaListener(
        topics = "order.created.events",
        groupId = "notification-service"
    )
    public void handleOrderCreated(
        ConsumerRecord<String, OrderCreatedMessage> record,
        Acknowledgment acknowledgment
    ) {
        OrderCreatedMessage message = record.value();

        log.info(
            "Kafka event received. eventType=OrderCreated, orderId={}, messageId={}, customerId={}, partition={}, offset={}",
            message.orderId(),
            message.messageId(),
            message.customerId(),
            record.partition(),
            record.offset()
        );

        boolean processed = idempotentNotificationService.tryProcess(message);

        if (processed) {
            log.info("Kafka notification processed. messageId={}, orderId={}",
                message.messageId(), message.orderId()
            );
        } else {
            log.info("Kafka duplicate ignored. messageId={}, orderId={}",
                message.messageId(), message.orderId()
            );
        }

        acknowledgment.acknowledge();
    }
}
