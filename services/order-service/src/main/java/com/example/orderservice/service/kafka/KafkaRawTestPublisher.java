package com.example.orderservice.service.kafka;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

@Service
public class KafkaRawTestPublisher {

    private static final String ORDER_CREATED_TOPIC = "order.created.events";

    private final KafkaTemplate<String, String> kafkaTemplate;

	public KafkaRawTestPublisher(
        @Qualifier("rawStringKafkaTemplate") KafkaTemplate<String, String> kafkaTemplate
    ) {
		this.kafkaTemplate = kafkaTemplate;
	}

    public void publishInvalidOrderCreatedJson() {
        String invalidJson = """
                {"messageId":"BAD-JSON-1","orderId":"ORDER-BAD-1","customerId":"CUST","productId":"PROD","quantity":"not-a-number","amount":99.99,"createdAt":"2026-06-30T12:00:00Z"}
                """;

        kafkaTemplate.send(ORDER_CREATED_TOPIC, "ORDER-BAD-1", invalidJson);
    }
}
