package com.example.paymentservice;

public record PaymentRequest (
    String orderId,
    double amount
) {
}