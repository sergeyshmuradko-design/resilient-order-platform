package com.example.orderservice;

public record CreateOrderRequest (
    String customerId,
    String productId,
    int quantity
) {
}