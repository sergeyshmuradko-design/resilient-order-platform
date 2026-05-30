package com.example.orderservice.dto;

import java.time.Instant;

public record PaymentResponse (
    String paymentId,
    String orderId,
    String status,
    Instant authorizedAt
) {
}