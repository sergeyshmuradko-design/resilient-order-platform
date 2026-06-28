package com.example.notificationservice.service;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

import com.example.notificationservice.dto.OrderCreatedMessage;

@Component
public class KafkaOrderCreatedListener {

    private static final Logger log = LoggerFactory.getLogger(KafkaOrderCreatedListener.class);

    @KafkaListener(
        topics = "order.created.events",
        groupId = "notification-service"
    )
    public void handleOrderCreated(ConsumerRecord<String, OrderCreatedMessage> record) {
        OrderCreatedMessage message = record.value();

        log.info(
            "Kafka OrderCreated received. topic={}, partition={}, offset={}, key={}, orderId={}, messageId={}",
            record.topic(),
            record.partition(),
            record.offset(),
            record.key(),
            message.orderId(),
            message.messageId()
        );
    }
}
