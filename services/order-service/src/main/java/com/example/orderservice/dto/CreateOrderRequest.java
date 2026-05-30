package com.example.orderservice.dto;

public record CreateOrderRequest (
    String customerId,
    String productId,
    int quantity
) {
}