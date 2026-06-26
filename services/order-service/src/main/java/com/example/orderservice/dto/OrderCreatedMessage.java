package com.example.orderservice.dto;

import java.time.Instant;

public record OrderCreatedMessage(
    String messageId,
    String orderId,
    String customerId,
    String productId,
    int quantity,
    double amount,
    Instant createdAt
) {
}
