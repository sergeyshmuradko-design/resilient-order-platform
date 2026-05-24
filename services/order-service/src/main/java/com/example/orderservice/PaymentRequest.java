package com.example.orderservice;

public record PaymentRequest (
    String orderId,
    double amount
) {
}