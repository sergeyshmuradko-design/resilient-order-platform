package com.example.orderservice.service.kafka;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

import com.example.orderservice.dto.OrderCreatedMessage;

@Service
@ConditionalOnProperty(
    name = "app.messaging.kafka.enabled",
    havingValue = "true",
    matchIfMissing = true
)
public class KafkaOrderEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(KafkaOrderEventPublisher.class);
    private static final String ORDER_CREATED_TOPIC = "order.created.events";

    private final KafkaTemplate<String, OrderCreatedMessage> kafkaTemplate;

    public KafkaOrderEventPublisher(KafkaTemplate<String, OrderCreatedMessage> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    public void publish(OrderCreatedMessage message) {
        log.info(
            "Kafka publish requested. eventType=OrderCreated, orderId={}, messageId={}, customerId={}",
            message.orderId(),
            message.messageId(),
            message.customerId()
        );
        kafkaTemplate.send(ORDER_CREATED_TOPIC, message.orderId(), message)
            .whenComplete((result, ex) -> {
                if (ex != null) {
                    log.error("Kafka publish failed. orderId={}, messageId={}",
                        message.orderId(), message.messageId(), ex
                    );
                } else {
                    log.info("Kafka publish success. topic={}, partition={}, offset={}, orderId={}",
                        result.getRecordMetadata().topic(),
                        result.getRecordMetadata().partition(),
                        result.getRecordMetadata().offset(),
                        message.orderId()
                    );
                }
            });
    }
}
