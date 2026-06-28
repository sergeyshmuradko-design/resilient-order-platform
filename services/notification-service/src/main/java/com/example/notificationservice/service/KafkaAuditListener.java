package com.example.notificationservice.service;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

import com.example.notificationservice.dto.OrderCreatedMessage;

@Component
public class KafkaAuditListener {

    private static final Logger log = LoggerFactory.getLogger(KafkaAuditListener.class);

    @KafkaListener(
        topics = "order.created.events",
        groupId = "audit-service"
    )
    public void auditOrderCreated(ConsumerRecord<String, OrderCreatedMessage> record) {
        OrderCreatedMessage message = record.value();

        log.info(
            "Audit Kafka event received. group=audit-service, partition={}, offset={}, key={}, orderId={}, messageId={}",
            record.partition(),
            record.offset(),
            record.key(),
            message.orderId(),
            message.messageId()
        );
    }
}
