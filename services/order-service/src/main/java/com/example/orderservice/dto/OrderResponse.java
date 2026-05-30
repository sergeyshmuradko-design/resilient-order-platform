package com.example.orderservice.dto;

import java.time.Instant;

public record OrderResponse (
    String orderId,
    String customerId,
    String productId,
    int quantity,
    double amount,
    String orderStatus,
    String paymentStatus,
    Instant createdAt
) {
}