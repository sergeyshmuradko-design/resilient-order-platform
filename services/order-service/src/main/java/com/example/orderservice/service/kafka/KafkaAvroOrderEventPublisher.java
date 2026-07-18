package com.example.orderservice.service.kafka;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

import com.example.orderservice.avro.OrderCreatedEvent;

@Service
@ConditionalOnProperty(
    name = "app.messaging.kafka.enabled",
    havingValue = "true",
    matchIfMissing = true
)
public class KafkaAvroOrderEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(KafkaAvroOrderEventPublisher.class);

    private static final String TOPIC = "order.created.events.avro";

    private final KafkaTemplate<String, OrderCreatedEvent> kafkaTemplate;

	public KafkaAvroOrderEventPublisher(
        @Qualifier("avroOrderCreatedKafkaTemplate") KafkaTemplate<String, OrderCreatedEvent> kafkaTemplate
    ) {
		this.kafkaTemplate = kafkaTemplate;
	}

    public void publish(OrderCreatedEvent event) {
        kafkaTemplate.send(TOPIC, event.getOrderId().toString(), event)
            .whenComplete((result, ex) -> {
                if (ex != null) {
                    log.error(
                        "Avro Kafka publish failed. orderId={}, messageId={}",
                        event.getOrderId(),
                        event.getMessageId(),
                        ex
                    );
                } else {
                    log.info(
                        "Avro Kafka publish success. topic={}, partition={}, offset={}, orderId={}",
                        result.getRecordMetadata().topic(),
                        result.getRecordMetadata().partition(),
                        result.getRecordMetadata().offset(),
                        event.getOrderId()
                    );
                }
            });
    }
}
