package com.example.orderservice.dto;

public record LoginRequest(
    String username,
    String password
) {
}
