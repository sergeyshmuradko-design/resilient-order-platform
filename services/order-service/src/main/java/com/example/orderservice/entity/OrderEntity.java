package com.example.orderservice.entity;

import java.time.Instant;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "orders")
public class OrderEntity {
    
    @Id
    private String orderId;

    private String customerId;
    private String productId;
    private int quantity;
    private double amount;
    private String orderStatus;
    private String paymentStatus;
    private Instant createdAt;

    protected OrderEntity() {}

    public OrderEntity(
        String orderId,
        String customerId,
        String productId,
        int quantity,
        double amount,
        String orderStatus,
        String paymentStatus,
        Instant createdAt
    ) {
        this.orderId = orderId;
        this.customerId = customerId;
        this.productId = productId;
        this.quantity = quantity;
        this.amount = amount;
        this.orderStatus = orderStatus;
        this.paymentStatus = paymentStatus;
        this.createdAt = createdAt;
    }

    public String getOrderId() {
        return orderId;
    }
}
