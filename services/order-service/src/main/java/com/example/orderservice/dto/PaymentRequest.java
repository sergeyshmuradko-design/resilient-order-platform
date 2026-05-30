package com.example.orderservice.dto;

public record PaymentRequest (
    String orderId,
    double amount
) {
}