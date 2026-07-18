package com.example.orderservice.controller;

import java.time.Instant;
import java.util.UUID;

import org.springframework.context.annotation.Profile;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.orderservice.dto.OrderCreatedMessage;
import com.example.orderservice.service.kafka.KafkaOrderEventPublisher;
import com.example.orderservice.service.kafka.KafkaRawTestPublisher;

import org.springframework.web.bind.annotation.PostMapping;

@Profile("kafka")
@RestController
@RequestMapping("/kafka")
public class KafkaTestController {

    private final KafkaOrderEventPublisher kafkaOrderEventPublisher;
    private final KafkaRawTestPublisher kafkaRawTestPublisher;

    public KafkaTestController(
        KafkaOrderEventPublisher kafkaOrderEventPublisher,
        KafkaRawTestPublisher kafkaRawTestPublisher
    ) {
        this.kafkaOrderEventPublisher = kafkaOrderEventPublisher;
        this.kafkaRawTestPublisher = kafkaRawTestPublisher;
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/publish-test")
    public ResponseEntity<Void> publishTestEvent() {
        OrderCreatedMessage message = new OrderCreatedMessage(
            UUID.randomUUID().toString(),
            "ORDER-KAFKA-" + UUID.randomUUID(),
            "CUST-KAFKA",
            "PROD-KAFKA",
            1,
            99.99,
            Instant.now()
        );

        kafkaOrderEventPublisher.publish(message);

        return ResponseEntity.accepted().build();
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/publish-duplicate-test")
    public ResponseEntity<Void> publishDuplicateTestEvent() {
        OrderCreatedMessage message = new OrderCreatedMessage(
            "DUPLICATE-MESSAGE-ID-1",
            "ORDER-DUPLICATE-1",
            "CUST-KAFKA",
            "PROD-KAFKA",
            1,
            99.99,
            Instant.now()
        );

        kafkaOrderEventPublisher.publish(message);

        return ResponseEntity.accepted().build();
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/publish-invalid-json")
    public ResponseEntity<Void> publishInvalidJson() {
        kafkaRawTestPublisher.publishInvalidOrderCreatedJson();
        return ResponseEntity.accepted().build();
    }

}
