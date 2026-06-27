package com.example.orderservice.dto;

public record RabbitPublishResult(
    boolean confirmed,
    boolean returned,
    String reason
) {
    public boolean success() {
        return confirmed && !returned;
    }
}
