package com.example.orderservice.dto;

import java.time.Instant;

import com.example.orderservice.entity.OrderEntity;

public record OrderSummaryResponse(
    String orderId,
    String customerId,
    String productId,
    int quantity,
    double amount,
    String orderStatus,
    String paymentStatus,
    Instant createdAt
) {
    public static OrderSummaryResponse from(OrderEntity entity) {
        return new OrderSummaryResponse(
            entity.getOrderId(),
            entity.getCustomerId(),
            entity.getProductId(),
            entity.getQuantity(),
            entity.getAmount(),
            entity.getOrderStatus(),
            entity.getPaymentStatus(),
            entity.getCreatedAt()
        );
    }
}
