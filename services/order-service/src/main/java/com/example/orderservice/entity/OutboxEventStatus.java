package com.example.orderservice.entity;

public enum OutboxEventStatus {
    NEW,
    PROCESSING,
    PUBLISHED,
    RETURNED,
    FAILED
}
