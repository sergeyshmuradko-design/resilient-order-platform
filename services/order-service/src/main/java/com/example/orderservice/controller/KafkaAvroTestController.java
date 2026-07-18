package com.example.orderservice.controller;

import java.time.Instant;
import java.util.UUID;

import org.springframework.context.annotation.Profile;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.orderservice.avro.OrderCreatedEvent;
import com.example.orderservice.service.kafka.KafkaAvroOrderEventPublisher;
import org.springframework.web.bind.annotation.PostMapping;

@Profile("kafka")
@RestController
@RequestMapping("/kafka-avro")
public class KafkaAvroTestController {

    private final KafkaAvroOrderEventPublisher publisher;

	public KafkaAvroTestController(KafkaAvroOrderEventPublisher publisher) {
		this.publisher = publisher;
	}

    // TODO: Later: move Avro schemas to separate contracts repository/artifact.
    // Do not use local Gradle project dependency if services are intended to become independent repositories.
    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/publish-test")
    public ResponseEntity<Void> publishTestEvent() {
        OrderCreatedEvent event = OrderCreatedEvent.newBuilder()
            .setMessageId(UUID.randomUUID().toString())
            .setOrderId("ORDER-AVRO-" + UUID.randomUUID())
            .setCustomerId("CUST-AVRO")
            .setProductId("PROD-AVRO")
            .setQuantity(1)
            .setAmount(99.99)
            .setCreatedAt(Instant.now().toString())
            .setSource("order-service")
            .build();

        publisher.publish(event);

        return ResponseEntity.accepted().build();
    }
    
}
