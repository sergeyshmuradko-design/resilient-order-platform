package com.example.orderservice.controller;

import org.springframework.context.annotation.Profile;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.orderservice.service.OutboxPublisher;
import org.springframework.web.bind.annotation.PostMapping;

@Profile("rabbit")
@RestController
@RequestMapping("/outbox")
public class OutboxController {

    private final OutboxPublisher outboxPublisher;

    public OutboxController(OutboxPublisher outboxPublisher) {
        this.outboxPublisher = outboxPublisher;
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/publish")
    public ResponseEntity<Void> publish() {
        outboxPublisher.publishNewEvents();
        return ResponseEntity.accepted().build();
    }
}
