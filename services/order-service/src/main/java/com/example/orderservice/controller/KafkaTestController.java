package com.example.orderservice.controller;

import java.time.Instant;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.orderservice.dto.OrderCreatedMessage;
import com.example.orderservice.service.kafka.KafkaOrderEventPublisher;
import org.springframework.web.bind.annotation.PostMapping;

@RestController
@RequestMapping("/kafka")
public class KafkaTestController {

    private final KafkaOrderEventPublisher kafkaOrderEventPublisher;

    public KafkaTestController(KafkaOrderEventPublisher kafkaOrderEventPublisher) {
        this.kafkaOrderEventPublisher = kafkaOrderEventPublisher;
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
    
}
