package com.example.notificationservice.service;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

import com.example.orderservice.avro.OrderCreatedEvent;

@Component
public class KafkaAvroOrderCreatedListener {

    private static final Logger log = LoggerFactory.getLogger(KafkaAvroOrderCreatedListener.class);

    @KafkaListener(
        topics = "order.created.events.avro",
        groupId = "notification-service-avro",
        containerFactory = "avroKafkaListenerContainerFactory"
    )
    public void handleOrderCreated(ConsumerRecord<String, OrderCreatedEvent> record) {
        OrderCreatedEvent event = record.value();

        log.info(
            "Avro OrderCreated received. partition={}, offset={}, key={}, orderId={}, messageId={}, quantity={}, source={}",
            record.partition(),
            record.offset(),
            record.key(),
            event.getOrderId(),
            event.getMessageId(),
            event.getQuantity(),
            event.getSource()
        );
    }
}
